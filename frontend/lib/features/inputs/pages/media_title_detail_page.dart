import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/services/media_title_list_actions.dart';
import 'package:frontend/features/inputs/widgets/media_title_poster_thumbnail.dart';
import 'package:frontend/features/productivity/widgets/transparent_form_panel.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaTitleDetailPage extends StatefulWidget {
  const MediaTitleDetailPage({
    super.key,
    required this.mediaTitleId,
    this.mediaTitle,
    this.actions,
  });

  final RecordId mediaTitleId;
  final MediaTitle? mediaTitle;
  final MediaTitleListTileActions? actions;

  @override
  State<MediaTitleDetailPage> createState() => _MediaTitleDetailPageState();
}

class _MediaTitleDetailPageState extends State<MediaTitleDetailPage> {
  bool _deleting = false;
  MediaTitle? _cachedMediaTitle;
  bool _hydrationRequested = false;
  bool _cacheBootstrapScheduled = false;

  MediaTitleListTileActions get _actions =>
      widget.actions ??
      MediaTitleListActions(CompanionAnvilApp.instance.apiClient);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureHydrated();
      _scheduleCacheBootstrap();
    });
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
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _buildChip(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      backgroundColor: scheme.secondaryContainer,
      labelStyle: TextStyle(color: scheme.onSecondaryContainer),
    );
  }

  Widget _buildBody(MediaTitle mediaTitle) {
    final theme = Theme.of(context);
    final metadata = <String>[
      mediaTypeLabel(mediaTitle.mediaType),
      if (mediaTitle.year != null) '${mediaTitle.year}',
      if (mediaTitle.runtimeMinutes != null) '${mediaTitle.runtimeMinutes} min',
      if (mediaTitle.rating != null)
        '★ ${mediaTitle.rating!.toStringAsFixed(1)}',
      if (mediaTitle.voteCount != null) '${mediaTitle.voteCount} votes',
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TransparentFormPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: MediaTitlePosterThumbnail(
                  posterUrl: mediaTitle.posterUrl,
                  width: 180,
                  height: 270,
                  borderRadius: 12,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                mediaTitle.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (metadata.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    metadata.join(' · '),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              if (mediaTitle.genres.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final genre in mediaTitle.genres)
                        _buildChip(context, genre),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openImdbUrl(mediaTitle.imdbUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open on IMDb'),
              ),
            ],
          ),
        ),
        if (mediaTitle.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 16),
          TransparentFormPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plot',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(mediaTitle.description!.trim()),
              ],
            ),
          ),
        ],
        if (mediaTitle.cast.isNotEmpty) ...[
          const SizedBox(height: 16),
          TransparentFormPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cast',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final member in mediaTitle.cast)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      member.character == null || member.character!.isEmpty
                          ? member.name
                          : '${member.name} as ${member.character}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordBloc, RecordState>(
      builder: (context, state) {
        final mediaTitle = _resolveMediaTitle(state);
        return Scaffold(
          appBar: AppBar(
            title: Text(mediaTitle?.name ?? 'Movies & TV'),
            actions: [
              if (mediaTitle != null)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _deleting
                      ? null
                      : () => _confirmDelete(mediaTitle),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: mediaTitle == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(mediaTitle),
        );
      },
    );
  }
}
