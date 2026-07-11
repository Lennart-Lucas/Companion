import 'package:flutter/material.dart';
import 'package:frontend/features/inputs/models/media_watch_entry.dart';
import 'package:frontend/features/inputs/services/media_watch_progress.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class MediaTitleEpisodeLog extends StatelessWidget {
  const MediaTitleEpisodeLog({
    super.key,
    required this.episodes,
    required this.watchEntries,
    this.nextEpisode,
    this.onDeleteEntry,
    this.isMovie = false,
  });

  final List<ImdbEpisodeSummary> episodes;
  final List<MediaWatchEntry> watchEntries;
  final ImdbEpisodeSummary? nextEpisode;
  final void Function(MediaWatchEntry entry)? onDeleteEntry;
  final bool isMovie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (isMovie) {
      final entry = watchEntries.cast<MediaWatchEntry?>().firstWhere(
            (e) => e?.seasonNumber == null && e?.episodeNumber == null,
            orElse: () => null,
          );
      if (entry == null) {
        return TrackerRowPanel(
          child: Text(
            'Not watched yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        );
      }
      return TrackerRowPanel(
        child: _EpisodeRow(
          label: 'Watched',
          subtitle: _formatWatchedAt(entry.watchedAt),
          isWatched: true,
          isNext: false,
          onDelete: onDeleteEntry == null ? null : () => onDeleteEntry!(entry),
        ),
      );
    }

    if (episodes.isEmpty) {
      return TrackerRowPanel(
        child: Text(
          'Episode list unavailable',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      );
    }

    final watchedKeys = {
      for (final entry in watchEntries)
        if (entry.seasonNumber != null && entry.episodeNumber != null)
          '${entry.seasonNumber}:${entry.episodeNumber}': entry,
    };

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Episode log',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final episode in episodes) ...[
            () {
              final key = '${episode.seasonNumber}:${episode.episodeNumber}';
              final entry = watchedKeys[key];
              final isWatched = entry != null;
              final isNext = nextEpisode != null &&
                  nextEpisode!.seasonNumber == episode.seasonNumber &&
                  nextEpisode!.episodeNumber == episode.episodeNumber &&
                  !isWatched;
              return _EpisodeRow(
                label:
                    'S${episode.seasonNumber} E${episode.episodeNumber} · ${episode.title}',
                subtitle: isWatched ? _formatWatchedAt(entry.watchedAt) : null,
                isWatched: isWatched,
                isNext: isNext,
                onDelete: entry != null && onDeleteEntry != null
                    ? () => onDeleteEntry!(entry)
                    : null,
              );
            }(),
          ],
        ],
      ),
    );
  }

  static String _formatWatchedAt(DateTime watchedAt) {
    final local = watchedAt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return 'Watched $y-$m-$d';
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.label,
    this.subtitle,
    required this.isWatched,
    required this.isNext,
    this.onDelete,
  });

  final String label;
  final String? subtitle;
  final bool isWatched;
  final bool isNext;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = isNext
        ? scheme.primaryContainer.withValues(alpha: 0.45)
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWatched ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: isWatched
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isNext ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isNext)
                  Text(
                    'Next up',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Remove log entry',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.undo, size: 18),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
