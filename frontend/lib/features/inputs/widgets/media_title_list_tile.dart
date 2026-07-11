import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/services/media_title_list_actions.dart';
import 'package:frontend/features/inputs/widgets/media_title_poster_thumbnail.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

enum MediaTitleListMenuAction { deleteTitle }

class MediaTitleListTile extends StatelessWidget {
  const MediaTitleListTile({
    super.key,
    required this.mediaTitle,
    required this.actions,
    this.onTap,
    this.onDeleted,
    this.inGrid = false,
  });

  final MediaTitle mediaTitle;
  final MediaTitleListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool inGrid;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<RecordBloc, RecordState, MediaTitle>(
      selector: (state) {
        final cached = state.snapshot.records[mediaTitle.id]?.record;
        return cached is MediaTitle ? cached : mediaTitle;
      },
      builder: (context, resolved) {
        return _MediaTitleListTileBody(
          mediaTitle: resolved,
          actions: actions,
          onTap: onTap,
          onDeleted: onDeleted,
          inGrid: inGrid,
        );
      },
    );
  }
}

class _MediaTitleListTileBody extends StatefulWidget {
  const _MediaTitleListTileBody({
    required this.mediaTitle,
    required this.actions,
    this.onTap,
    this.onDeleted,
    this.inGrid = false,
  });

  final MediaTitle mediaTitle;
  final MediaTitleListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool inGrid;

  @override
  State<_MediaTitleListTileBody> createState() => _MediaTitleListTileBodyState();
}

class _MediaTitleListTileBodyState extends State<_MediaTitleListTileBody> {
  bool _busy = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete title?'),
        content: Text('Remove "${widget.mediaTitle.name}" from your library?'),
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

    setState(() => _busy = true);
    try {
      await widget.actions.deleteMediaTitle(widget.mediaTitle.id);
      widget.onDeleted?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildMetaChip({
    required BuildContext context,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final mediaTitle = widget.mediaTitle;
    final chips = <Widget>[
      _buildMetaChip(
        context: context,
        label: mediaTypeLabel(mediaTitle.mediaType),
      ),
      if (mediaTitle.year != null)
        _buildMetaChip(context: context, label: '${mediaTitle.year}'),
      if (mediaTitle.rating != null)
        _buildMetaChip(
          context: context,
          label: '★ ${mediaTitle.rating!.toStringAsFixed(1)}',
        ),
    ];

    return Opacity(
      opacity: _busy ? 0.6 : 1.0,
      child: Padding(
        padding: widget.inGrid
            ? EdgeInsets.zero
            : const EdgeInsets.only(
                bottom: CompanionFormStyles.taskRowVerticalGap,
              ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _busy ? null : widget.onTap,
            borderRadius: BorderRadius.circular(
              CompanionFormStyles.taskRowPanelRadius,
            ),
            child: TrackerRowPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MediaTitlePosterThumbnail(posterUrl: mediaTitle.posterUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mediaTitle.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (mediaTitle.description?.trim().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              mediaTitle.description!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        if (chips.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: chips,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<MediaTitleListMenuAction>(
                    enabled: !_busy,
                    onSelected: (action) {
                      if (action == MediaTitleListMenuAction.deleteTitle) {
                        _confirmDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: MediaTitleListMenuAction.deleteTitle,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
