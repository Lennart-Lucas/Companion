import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/logged_trend_chart.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_stat_items.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_month_success_calendar.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_stats_highlight_row.dart';

class TrackerStatsSection extends StatelessWidget {
  const TrackerStatsSection({
    super.key,
    required this.tracker,
    required this.stats,
    required this.listToday,
    required this.displayedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onGoToCurrentMonth,
    this.onDaySelected,
    this.showHighlightRow = true,
    this.showStatCards = true,
  });

  final Tracker tracker;
  final TrackerStats stats;
  final DateTime listToday;
  final DateTime displayedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onGoToCurrentMonth;
  final ValueChanged<DateTime>? onDaySelected;
  final bool showHighlightRow;
  final bool showStatCards;

  @override
  Widget build(BuildContext context) {
    final cards = buildTrackerStatItems(tracker: tracker, stats: stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHighlightRow) ...[
          const SizedBox(height: 16),
          TrackerStatsHighlightRow(stats: stats),
          const SizedBox(height: 16),
        ],
        if (showStatCards) ...[
          Wrap(
            spacing: CompanionFormStyles.taskListChipGap,
            runSpacing: CompanionFormStyles.taskListChipGap,
            children: [
              for (final card in cards)
                TrackerStatCard(
                  label: card.label,
                  value: card.value,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        LoggedTrendChart(
          weeklyRates: stats.weeklySuccessRates,
          weeklyHasData: stats.weeklyHasData,
          listToday: listToday,
          rateSubtitle: 'Weekly success rate',
          entityStartDate: tracker.startDate,
          formatStartDate: formatProjectDate,
          emptyEntityLabel: 'habit',
        ),
        const SizedBox(height: 16),
        TrackerMonthSuccessCalendar(
          displayedMonth: displayedMonth,
          listToday: listToday,
          dayOutcomes: stats.dayOutcomes,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
          onGoToCurrentMonth: onGoToCurrentMonth,
          onDaySelected: onDaySelected,
          trackerStartDate: tracker.startDate,
          trackerEndDate: tracker.endDate,
        ),
      ],
    );
  }
}

class TrackerStatCard extends StatelessWidget {
  const TrackerStatCard({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 156,
      child: TrackerRowPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
