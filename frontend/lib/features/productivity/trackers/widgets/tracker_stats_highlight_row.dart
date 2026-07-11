import 'package:flutter/material.dart';
import 'package:frontend/core/ui/outcome_colors.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

/// Layout for [TrackerStatsHighlightRow].
enum TrackerStatsHighlightLayout {
  /// Four cards in a single horizontal row (phone).
  horizontal,

  /// Full-width horizontal cards stacked vertically (sidebar).
  vertical,
}

/// Highlight cards for tracker performance summaries.
class TrackerStatsHighlightRow extends StatelessWidget {
  const TrackerStatsHighlightRow({
    super.key,
    required this.stats,
    this.layout = TrackerStatsHighlightLayout.horizontal,
    this.direction = Axis.horizontal,
  });

  static const _consistencyTooltip =
      'Consistency\n\n'
      'Measures recent performance over the last 30 scheduled days.\n\n'
      'Consistency = completed ÷ scheduled × 100\n\n'
      'Unlike habit strength, this reacts fairly quickly to how you have been doing lately.';

  final TrackerStats stats;
  final TrackerStatsHighlightLayout layout;
  final Axis direction;

  TrackerStatsHighlightLayout get _resolvedLayout {
    if (layout != TrackerStatsHighlightLayout.horizontal) {
      return layout;
    }
    return direction == Axis.vertical
        ? TrackerStatsHighlightLayout.vertical
        : TrackerStatsHighlightLayout.horizontal;
  }

  @override
  Widget build(BuildContext context) {
    final successPercent = (stats.successRate * 100).round();
    final consistencyPercent = (stats.consistency * 100).round();
    final streakFraction = stats.bestStreak == 0
        ? 0.0
        : (stats.currentStreak / stats.bestStreak).clamp(0.0, 1.0);

    final sidebarStyle = _resolvedLayout == TrackerStatsHighlightLayout.vertical;

    final cards = [
      _TrackerHighlightCard(
        ringFraction: stats.successRate.clamp(0.0, 1.0),
        ringColor: trackerStrengthHighColor,
        ringCenterText: '$successPercent%',
        valueText: '$successPercent%',
        label: 'Success rate',
        sidebarStyle: sidebarStyle,
      ),
      _TrackerHighlightCard(
        ringFraction: streakFraction,
        ringColor: trackerStrengthHighColor,
        ringCenterText: '${stats.currentStreak}',
        valueText: '${stats.currentStreak} / ${stats.bestStreak} days',
        label: 'Streak vs best',
        sidebarStyle: sidebarStyle,
      ),
      _TrackerHighlightCard(
        ringFraction: stats.consistency.clamp(0.0, 1.0),
        ringColor: trackerStrengthMidColor,
        ringCenterText: '$consistencyPercent%',
        valueText:
            '${stats.consistencyCompleted}/${stats.consistencyScheduled}',
        label: 'Consistency',
        tooltip: _consistencyTooltip,
        sidebarStyle: sidebarStyle,
      ),
    ];

    switch (_resolvedLayout) {
      case TrackerStatsHighlightLayout.vertical:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              cards[i],
            ],
          ],
        );
      case TrackerStatsHighlightLayout.horizontal:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
    }
  }
}

class _TrackerHighlightCard extends StatelessWidget {
  const _TrackerHighlightCard({
    required this.ringFraction,
    required this.ringColor,
    required this.ringCenterText,
    required this.valueText,
    required this.label,
    this.tooltip,
    this.sidebarStyle = false,
  });

  static const _ringSize = 52.0;
  static const _sidebarRingSize = 56.0;

  final double ringFraction;
  final Color ringColor;
  final String ringCenterText;
  final String valueText;
  final String label;
  final String? tooltip;
  final bool sidebarStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ringSize = sidebarStyle ? _sidebarRingSize : _ringSize;

    final card = TrackerRowPanel(
      child: Row(
        children: [
          TrackerProgressRing(
            fraction: ringFraction,
            color: ringColor,
            size: ringSize,
            strokeWidth: sidebarStyle ? 5.0 : 4.5,
            center: Text(
              ringCenterText,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withValues(alpha: 0.92),
                height: 1,
              ),
            ),
          ),
          SizedBox(width: sidebarStyle ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  valueText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (sidebarStyle
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (tooltip == null) return card;

    return Tooltip(
      message: tooltip!,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 200),
      child: card,
    );
  }
}
