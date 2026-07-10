import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/pages/media_title_detail_page.dart';
import 'package:frontend/features/inputs/services/imdb_person_api.dart';
import 'package:frontend/features/inputs/services/media_title_list_actions.dart';
import 'package:frontend/features/inputs/services/media_title_repository.dart';
import 'package:frontend/features/inputs/widgets/media_title_poster_thumbnail.dart';
import 'package:frontend/features/productivity/forms/companion_layout.dart';

Future<void> showActorFilmographySheet(
  BuildContext context, {
  required MediaTitleCastMember member,
  MediaTitleListTileActions? actions,
  ImdbPersonApi? personApi,
  MediaTitleRepository? mediaTitleRepository,
}) {
  final compact = CompanionLayout.isCompact(context);
  final sheet = ActorFilmographySheet(
    member: member,
    actions: actions,
    personApi: personApi,
    mediaTitleRepository: mediaTitleRepository,
  );
  if (compact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => sheet,
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: sheet,
      ),
    ),
  );
}

class ActorFilmographySheet extends StatefulWidget {
  const ActorFilmographySheet({
    super.key,
    required this.member,
    this.actions,
    this.personApi,
    this.mediaTitleRepository,
  });

  final MediaTitleCastMember member;
  final MediaTitleListTileActions? actions;
  final ImdbPersonApi? personApi;
  final MediaTitleRepository? mediaTitleRepository;

  @override
  State<ActorFilmographySheet> createState() => _ActorFilmographySheetState();
}

class _ActorFilmographySheetState extends State<ActorFilmographySheet> {
  bool _loading = false;
  String? _error;
  List<ImdbFilmographyEntry> _entries = const [];

  ImdbPersonApi get _personApi =>
      widget.personApi ?? defaultImdbPersonApi();

  MediaTitleRepository get _repository =>
      widget.mediaTitleRepository ??
      MediaTitleRepository(CompanionAnvilApp.instance.apiClient);

  MediaTitleListTileActions get _actions =>
      widget.actions ??
      MediaTitleListActions(CompanionAnvilApp.instance.apiClient);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final nameId = widget.member.imdbNameId;
    if (nameId == null || nameId.isEmpty) {
      setState(() {
        _error = 'Re-import from IMDb to load actor credits.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await _personApi.fetchFilmography(nameId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  MediaTitle? _libraryTitleForImdbId(RecordState state, String imdbId) {
    for (final cached in state.snapshot.records.values) {
      final record = cached.record;
      if (record is MediaTitle && record.imdbId == imdbId) {
        return record;
      }
    }
    return null;
  }

  Future<void> _openTitle(ImdbFilmographyEntry entry) async {
    final bloc = context.read<RecordBloc>();
    final existing = _libraryTitleForImdbId(bloc.state, entry.imdbId);
    if (existing != null) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MediaTitleDetailPage(
            mediaTitleId: existing.id,
            mediaTitle: existing,
            actions: _actions,
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final created = await _repository.createFromImdbId(entry.imdbId);
      if (!mounted) return;
      bloc.add(
        GetRecordRequested(
          recordType: 'media_titles',
          recordId: created.id,
        ),
      );
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MediaTitleDetailPage(
            mediaTitleId: created.id,
            mediaTitle: created,
            actions: _actions,
          ),
        ),
      );
    } on MediaTitleAlreadyExistsException {
      final retry = _libraryTitleForImdbId(bloc.state, entry.imdbId);
      if (retry != null && mounted) {
        Navigator.of(context).pop();
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MediaTitleDetailPage(
              mediaTitleId: retry.id,
              mediaTitle: retry,
              actions: _actions,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final member = widget.member;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (member.character?.isNotEmpty == true)
                      Text(
                        'as ${member.character}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Filmography',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading && _entries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _entries.isEmpty
                    ? Center(child: Text(_error!))
                    : _entries.isEmpty
                        ? Center(
                            child: Text(
                              'No credits found',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            itemCount: _entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              final metadata = <String>[
                                mediaTypeLabel(entry.mediaType),
                                if (entry.year != null) '${entry.year}',
                              ].join(' · ');
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: MediaTitlePosterThumbnail(
                                  posterUrl: entry.posterUrl,
                                  width: 40,
                                  height: 60,
                                  borderRadius: 6,
                                ),
                                title: Text(entry.name),
                                subtitle: metadata.isEmpty
                                    ? null
                                    : Text(metadata),
                                onTap: _loading
                                    ? null
                                    : () => _openTitle(entry),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
