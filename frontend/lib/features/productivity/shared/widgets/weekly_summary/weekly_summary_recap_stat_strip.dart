import 'package:flutter/material.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class WeeklySummaryRecapStatStrip extends StatelessWidget {
  const WeeklySummaryRecapStatStrip({super.key, required this.recap});

  final WeeklyRecapStats recap;

  static const _spreadBreakpoint = 720.0;
  static const _tileMinWidth = 168.0;
  static const _tileSpacing = 12.0;
  static const _stripHeight = 104.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final consistencyPercent = (recap.consistencyPercent * 100).round();
    final trackersFraction = recap.trackersTotal == 0
        ? 0.0
        : recap.trackersOnStreak / recap.trackersTotal;
    final goalsFraction = recap.goalsTotal == 0
        ? 0.0
        : recap.goalsOnTrack / recap.goalsTotal;
    final trackersValue = recap.trackersTotal == 0
        ? '—'
        : '${recap.trackersOnStreak}/${recap.trackersTotal}';
    final goalsValue = recap.goalsTotal == 0
        ? '—'
        : '${recap.goalsOnTrack}/${recap.goalsTotal}';

    final tiles = [
      _RecapStatTile(
        ringFraction: 1.0,
        ringColor: scheme.primary,
        ringCenterText: '${recap.checkInsLogged}',
        valueText: '${recap.checkInsLogged}',
        label: 'Check-ins logged',
      ),
      _RecapStatTile(
        ringFraction: 1.0,
        ringColor: trackerStrengthHighColor,
        ringCenterText: '${recap.tasksCompleted}',
        valueText: '${recap.tasksCompleted}',
        label: 'Tasks completed',
      ),
      _RecapStatTile(
        ringFraction: trackersFraction.clamp(0.0, 1.0),
        ringColor: trackerStrengthMidColor,
        ringCenterText: trackersValue,
        valueText: trackersValue,
        label: 'Trackers on-streak',
      ),
      _RecapStatTile(
        ringFraction: goalsFraction.clamp(0.0, 1.0),
        ringColor: trackerStrengthHighColor,
        ringCenterText: goalsValue,
        valueText: goalsValue,
        label: 'Goals on track',
      ),
      _RecapStatTile(
        ringFraction: recap.consistencyPercent.clamp(0.0, 1.0),
        ringColor: companionTrackerBlue,
        ringCenterText: '$consistencyPercent%',
        valueText: '$consistencyPercent%',
        label: 'Consistency',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'LAST WEEK RECAP',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.55),
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final spreadEvenly =
                constraints.maxWidth >= _spreadBreakpoint &&
                !CompanionLayout.isCompact(context);

            if (spreadEvenly) {
              return SizedBox(
                height: _stripHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: _tileSpacing),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                ),
              );
            }

            return SizedBox(
              height: _stripHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tiles.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: _tileSpacing),
                itemBuilder: (context, index) => SizedBox(
                  width: _tileMinWidth,
                  child: tiles[index],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RecapStatTile extends StatelessWidget {
  const _RecapStatTile({
    required this.ringFraction,
    required this.ringColor,
    required this.valueText,
    required this.label,
    this.ringCenterText,
  });

  static const _ringSize = 52.0;

  final double ringFraction;
  final Color ringColor;
  final String? ringCenterText;
  final String valueText;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TrackerRowPanel(
      child: Row(
        children: [
          TrackerProgressRing(
            fraction: ringFraction,
            color: ringColor,
            size: _ringSize,
            strokeWidth: 4.5,
            center: ringCenterText == null
                ? null
                : Text(
                    ringCenterText!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.92),
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  valueText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
