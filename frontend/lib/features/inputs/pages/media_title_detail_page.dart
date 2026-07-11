import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/models/media_watch_entry.dart';
import 'package:frontend/features/inputs/services/media_episodes_api.dart';
import 'package:frontend/features/inputs/services/media_title_repository.dart';
import 'package:frontend/features/inputs/services/media_watch_progress.dart';
import 'package:frontend/features/inputs/services/media_watch_repository.dart';
import 'package:frontend/features/inputs/services/media_title_list_actions.dart';
import 'package:frontend/features/inputs/widgets/media_title_detail_sidebar.dart';
import 'package:frontend/features/inputs/widgets/media_title_notes_panel.dart';
import 'package:frontend/features/inputs/widgets/media_title_season_episodes_panel.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaTitleDetailPage extends StatefulWidget {
  const MediaTitleDetailPage({
    super.key,
    required this.mediaTitleId,
    this.mediaTitle,
    this.actions,
    this.watchRepository,
    this.episodesApi,
    this.mediaTitleRepository,
  });

  final RecordId mediaTitleId;
  final MediaTitle? mediaTitle;
  final MediaTitleListTileActions? actions;
  final MediaWatchRepository? watchRepository;
  final MediaEpisodesApi? episodesApi;
  final MediaTitleRepository? mediaTitleRepository;

  @override
  State<MediaTitleDetailPage> createState() => _MediaTitleDetailPageState();
}

class _MediaTitleDetailPageState extends State<MediaTitleDetailPage> {
  static const _mediaTitlesQuery =
      RecordQuery(recordType: 'media_titles', limit: 50);

  bool _deleting = false;
  bool _logging = false;
  bool _refreshing = false;
  bool _loadingWatchData = false;
  String? _watchDataError;
  String? _episodeLoadError;
  MediaTitle? _cachedMediaTitle;
  bool _hydrationRequested = false;
  bool _cacheBootstrapScheduled = false;
  List<MediaWatchEntry> _watchEntries = [];
  List<ImdbEpisodeSummary> _episodes = [];

  MediaTitleListTileActions get _actions =>
      widget.actions ??
      MediaTitleListActions(CompanionAnvilApp.instance.apiClient);

  MediaWatchRepository get _watchRepository =>
      widget.watchRepository ?? defaultMediaWatchRepository();

  MediaEpisodesApi get _episodesApi =>
      widget.episodesApi ?? defaultMediaEpisodesApi();

  MediaTitleRepository get _mediaTitleRepository =>
      widget.mediaTitleRepository ??
      MediaTitleRepository(CompanionAnvilApp.instance.apiClient);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchMediaTitle();
      _ensureHydrated();
      _scheduleCacheBootstrap();
      _loadWatchData();
    });
  }

  void _prefetchMediaTitle() {
    final bloc = context.read<RecordBloc>();
    if (bloc.state.snapshot.queries[_mediaTitlesQuery.queryKey] == null) {
      bloc.add(const QueryRecordsRequested(_mediaTitlesQuery));
    }
  }

  Future<void> _bootstrapMediaTitleFromCache() async {
    if (_resolveMediaTitle(context.read<RecordBloc>().state) != null) return;

    LocalRecordCacheService cache;
    try {
      cache = CompanionAnvilApp.instance.localCache;
    } on StateError {
      return;
    }

    final json = await cache.loadRecord('media_titles', widget.mediaTitleId);
    if (json == null || !mounted) return;

    setState(() {
      _cachedMediaTitle = MediaTitle.fromJson(json);
    });
    await _loadWatchData();
  }

  void _scheduleCacheBootstrap() {
    if (_cacheBootstrapScheduled) return;
    _cacheBootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _bootstrapMediaTitleFromCache();
    });
  }

  void _ensureHydrated() {
    if (_hydrationRequested) return;
    _hydrationRequested = true;
    context.read<RecordBloc>().add(
          GetRecordRequested(
            recordType: 'media_titles',
            recordId: widget.mediaTitleId,
          ),
        );
  }

  MediaTitle? _resolveMediaTitle(RecordState state) {
    final cached = state.snapshot.records[widget.mediaTitleId]?.record;
    if (cached is MediaTitle) return cached;
    if (_cachedMediaTitle != null) return _cachedMediaTitle;
    return widget.mediaTitle;
  }

  Future<void> _loadWatchData() async {
    final mediaTitle = _resolveMediaTitle(context.read<RecordBloc>().state);
    if (mediaTitle == null) return;

    setState(() {
      _loadingWatchData = true;
      _watchDataError = null;
      _episodeLoadError = null;
    });

    try {
      final entries =
          await _watchRepository.fetchWatchEntries(mediaTitle.id);
      List<ImdbEpisodeSummary> episodes = const [];
      String? episodeLoadError;
      if (isTvMediaType(mediaTitle.mediaType)) {
        try {
          episodes = await _episodesApi.fetchAllEpisodes(mediaTitle.imdbId);
        } catch (error) {
          episodes = const [];
          episodeLoadError = error.toString();
        }
      }
      if (!mounted) return;
      setState(() {
        _watchEntries = entries;
        _episodes = episodes;
        _episodeLoadError = episodeLoadError;
        _loadingWatchData = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingWatchData = false;
        _watchDataError = error.toString();
      });
    }
  }

  Future<void> _onRefresh() async {
    context.read<RecordBloc>().remoteCoordinator?.refreshQueryRecords(
          _mediaTitlesQuery,
        );
    context.read<RecordBloc>().add(
          GetRecordRequested(
            recordType: 'media_titles',
            recordId: widget.mediaTitleId,
          ),
        );
    await _loadWatchData();
  }

  Future<void> _onReimportFromImdb() async {
    final mediaTitle = _resolveMediaTitle(context.read<RecordBloc>().state);
    if (mediaTitle == null || _refreshing) return;

    setState(() => _refreshing = true);
    try {
      final updated = await _mediaTitleRepository.refreshFromImdb(mediaTitle.id);
      await _patchMediaTitle(updated);
      await _loadWatchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Re-imported from IMDb')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _patchMediaTitle(MediaTitle updated) async {
    setState(() => _cachedMediaTitle = updated);
    if (!mounted) return;
    context.read<RecordBloc>().add(
          GetRecordRequested(
            recordType: 'media_titles',
            recordId: updated.id,
          ),
        );
  }

  Future<void> _onWatchStatusChanged(String status) async {
    final mediaTitle = _resolveMediaTitle(context.read<RecordBloc>().state);
    if (mediaTitle == null) return;
    try {
      final updated = await _mediaTitleRepository.updateMediaTitle(
        mediaTitle.id,
        watchStatus: status,
      );
      await _patchMediaTitle(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _onUserRatingChanged(double? rating) async {
    final mediaTitle = _resolveMediaTitle(context.read<RecordBloc>().state);
    if (mediaTitle == null) return;
    try {
      final updated = await _mediaTitleRepository.updateMediaTitle(
        mediaTitle.id,
        userRating: rating,
        clearUserRating: rating == null,
      );
      await _patchMediaTitle(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _onNotesChanged(String? notes) async {
    final mediaTitle = _resolveMediaTitle(context.read<RecordBloc>().state);
    if (mediaTitle == null) return;
    if (mediaTitle.notes == notes) return;
    try {
      final updated = await _mediaTitleRepository.updateMediaTitle(
        mediaTitle.id,
        notes: notes,
        clearNotes: notes == null,
      );
      await _patchMediaTitle(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _onPrimaryAction(MediaTitle mediaTitle) async {
    if (_logging) return;
    setState(() => _logging = true);
    try {
      if (isTvMediaType(mediaTitle.mediaType)) {
        await _watchRepository.logNextEpisode(
          mediaTitle.id,
          _episodes,
          _watchEntries,
        );
      } else if (isMovieWatched(_watchEntries)) {
        final entry = _watchEntries.firstWhere(
          (e) => e.seasonNumber == null && e.episodeNumber == null,
        );
        await _watchRepository.deleteWatchEntry(mediaTitle.id, entry.id);
        await _watchRepository.markMovieWatched(mediaTitle.id);
      } else {
        await _watchRepository.markMovieWatched(mediaTitle.id);
      }
      await _loadWatchData();
      if (!mounted) return;
      final refreshed = _resolveMediaTitle(context.read<RecordBloc>().state);
      if (refreshed != null &&
          refreshed.watchStatus == MediaWatchStatus.planToWatch) {
        final updated = await _mediaTitleRepository.updateMediaTitle(
          mediaTitle.id,
          watchStatus: MediaWatchStatus.watching,
        );
        await _patchMediaTitle(updated);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _onToggleEpisode(
    ImdbEpisodeSummary episode,
    bool markWatched,
  ) async {
    final mediaTitle = _resolveMediaTitle(context.read<RecordBloc>().state);
    if (mediaTitle == null || _logging) return;

    setState(() => _logging = true);
    try {
      if (markWatched) {
        await _watchRepository.logEpisode(
          mediaTitle.id,
          seasonNumber: episode.seasonNumber,
          episodeNumber: episode.episodeNumber,
          episodeImdbId: episode.imdbId.isEmpty ? null : episode.imdbId,
          episodeTitle: episode.title,
        );
      } else {
        final entry = _watchEntries.firstWhere(
          (e) =>
              e.seasonNumber == episode.seasonNumber &&
              e.episodeNumber == episode.episodeNumber,
        );
        await _watchRepository.deleteWatchEntry(mediaTitle.id, entry.id);
      }
      await _loadWatchData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _onToggleMovie(bool markWatched) async {
    final mediaTitle = _resolveMediaTitle(context.read<RecordBloc>().state);
    if (mediaTitle == null || _logging) return;

    setState(() => _logging = true);
    try {
      if (markWatched) {
        await _watchRepository.markMovieWatched(mediaTitle.id);
      } else {
        final entry = _watchEntries.firstWhere(
          (e) => e.seasonNumber == null && e.episodeNumber == null,
        );
        await _watchRepository.deleteWatchEntry(mediaTitle.id, entry.id);
      }
      await _loadWatchData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _openImdbUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open IMDb link')),
      );
    }
  }

  Future<void> _confirmDelete(MediaTitle mediaTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete title?'),
        content: Text('Remove "${mediaTitle.name}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _actions.deleteMediaTitle(mediaTitle.id);
      if (!mounted) return;
      context.read<RecordBloc>().add(
            DeleteRecordRequested(
              recordType: 'media_titles',
              recordId: mediaTitle.id,
            ),
          );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _primaryActionLabel(MediaTitle mediaTitle) {
    if (!isTvMediaType(mediaTitle.mediaType)) {
      return isMovieWatched(_watchEntries) ? 'Rewatch' : 'Mark watched';
    }
    final next = findNextUnwatchedEpisode(_episodes, _watchEntries);
    if (next == null) return 'All caught up';
    return 'Log episode';
  }

  List<Widget> _mainContentChildren(MediaTitle mediaTitle) {
    final theme = Theme.of(context);
    final isTv = isTvMediaType(mediaTitle.mediaType);
    final nextEpisode = isTv
        ? findNextUnwatchedEpisode(_episodes, _watchEntries)
        : null;

    return [
      if (mediaTitle.description?.trim().isNotEmpty == true)
        TrackerRowPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Synopsis',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(mediaTitle.description!.trim()),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openImdbUrl(mediaTitle.imdbUrl),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open on IMDb'),
              ),
            ],
          ),
        ),
      if (mediaTitle.description?.trim().isNotEmpty == true)
        const SizedBox(height: 16),
      if (_episodeLoadError != null && isTv)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _episodeLoadError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      MediaTitleSeasonEpisodesPanel(
        episodes: _episodes,
        watchEntries: _watchEntries,
        nextEpisode: nextEpisode,
        isMovie: !isTv,
        toggleEnabled: !_logging,
        onToggleEpisode: isTv ? _onToggleEpisode : null,
        onToggleMovie: isTv ? null : _onToggleMovie,
      ),
      const SizedBox(height: 16),
      TrackerRowPanel(
        child: MediaTitleNotesPanel(
          notes: mediaTitle.notes,
          onNotesChanged: _onNotesChanged,
        ),
      ),
    ];
  }

  Widget _buildMainContent(MediaTitle mediaTitle) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _mainContentChildren(mediaTitle),
    );
  }

  Widget _buildBody(MediaTitle mediaTitle) {
    if (_loadingWatchData && _watchEntries.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_watchDataError != null && _watchEntries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _watchDataError!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadWatchData,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final isTv = isTvMediaType(mediaTitle.mediaType);
    final episodesSeen =
        isTv ? countWatchedTvEpisodes(_watchEntries) : null;
    final sidebar = MediaTitleDetailSidebar(
      mediaTitle: mediaTitle,
      isTv: isTv,
      episodeCount: isTv ? _episodes.length : null,
      episodesSeen: episodesSeen,
      onWatchStatusChanged: _onWatchStatusChanged,
      onUserRatingChanged: _onUserRatingChanged,
      actions: _actions,
    );

    if (CompanionLayout.isCompact(context)) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MediaTitleDetailSidebar(
            mediaTitle: mediaTitle,
            isTv: isTv,
            episodeCount: isTv ? _episodes.length : null,
            episodesSeen: episodesSeen,
            onWatchStatusChanged: _onWatchStatusChanged,
            onUserRatingChanged: _onUserRatingChanged,
            actions: _actions,
            compact: true,
          ),
          const SizedBox(height: 16),
          ..._mainContentChildren(mediaTitle),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sidebar,
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: scheme.outline.withValues(alpha: 0.2),
        ),
        Expanded(child: _buildMainContent(mediaTitle)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordBloc, RecordState>(
      builder: (context, state) {
        final mediaTitle = _resolveMediaTitle(state);
        final scheme = Theme.of(context).colorScheme;
        final backgroundIcon = resolveTaskCategoryIconData(
          iconName: 'Clapperboard',
          defaultIconName: 'Clapperboard',
          materialFallback: Icons.movie_outlined,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(mediaTitle?.name ?? 'Movies & TV'),
            backgroundColor: scheme.surface.withValues(alpha: 0.85),
            actions: [
              if (mediaTitle != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    onPressed: _logging ||
                            _deleting ||
                            _refreshing ||
                            (isTvMediaType(mediaTitle.mediaType) &&
                                _episodes.isNotEmpty &&
                                findNextUnwatchedEpisode(
                                      _episodes,
                                      _watchEntries,
                                    ) ==
                                    null)
                        ? null
                        : () => _onPrimaryAction(mediaTitle),
                    child: _logging
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_primaryActionLabel(mediaTitle)),
                  ),
                ),
                IconButton(
                  tooltip: 'Re-import from IMDb',
                  onPressed: _deleting || _refreshing
                      ? null
                      : _onReimportFromImdb,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _deleting || _refreshing
                      ? null
                      : () => _confirmDelete(mediaTitle),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          body: mediaTitle == null
              ? const Center(child: CircularProgressIndicator())
              : AnvilBackgroundIcon(
                  icon: backgroundIcon,
                  color: scheme.primary.withValues(alpha: 0.85),
                  opacity: 0.28,
                  baseSize: 260,
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: _buildBody(mediaTitle),
                  ),
                ),
        );
      },
    );
  }
}
