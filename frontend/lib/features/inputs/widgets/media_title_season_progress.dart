import 'package:flutter/material.dart';
import 'package:frontend/features/inputs/services/media_watch_progress.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

class MediaTitleSeasonProgress extends StatelessWidget {
  const MediaTitleSeasonProgress({
    super.key,
    required this.seasons,
    this.showMovieLabel = false,
  });

  final List<MediaSeasonProgress> seasons;
  final bool showMovieLabel;

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            showMovieLabel ? 'Watch progress' : 'Season progress',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < seasons.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _SeasonRow(progress: seasons[i], showMovieLabel: showMovieLabel),
          ],
          if (!showMovieLabel && seasons.isEmpty)
            Text(
              'Episode catalog unavailable',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}

class _SeasonRow extends StatelessWidget {
  const _SeasonRow({
    required this.progress,
    required this.showMovieLabel,
  });

  final MediaSeasonProgress progress;
  final bool showMovieLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = showMovieLabel
        ? progress.label.replaceFirst('0/1', 'Not watched').replaceFirst('1/1', 'Watched')
        : 'Season ${progress.seasonNumber} · ${progress.label}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            color: progress.isComplete
                ? scheme.primary
                : scheme.primary.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
