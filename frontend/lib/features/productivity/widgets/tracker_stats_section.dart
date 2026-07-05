import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/widgets/tracker_month_success_calendar.dart';
import 'package:frontend/features/productivity/widgets/tracker_success_trend_chart.dart';
import 'package:frontend/features/productivity/widgets/tracker_week_success_strip.dart';

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
  });

  final Tracker tracker;
  final TrackerStats stats;
  final DateTime listToday;
  final DateTime displayedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onGoToCurrentMonth;
  final ValueChanged<DateTime>? onDaySelected;

  String _percent(double value) => '${(value * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final cards = <_StatItem>[
      _StatItem('Current streak', '${stats.currentStreak}'),
      _StatItem('Best streak', '${stats.bestStreak}'),
      _StatItem('Total check-ins', '${stats.totalCheckIns}'),
      _StatItem('This week', _percent(stats.thisWeekPercent)),
      _StatItem('Succeeded', '${stats.succeeded}'),
      _StatItem('Missed', '${stats.missed}'),
      _StatItem('Skipped', '${stats.skipped}'),
      _StatItem('Success rate', _percent(stats.successRate)),
    ];

    if (tracker.checkInType == TrackerCheckInType.count) {
      final unit = stats.unitLabel ?? 'units';
      cards.addAll([
        _StatItem('Done $unit', _formatNum(stats.doneUnits)),
        _StatItem('Missed $unit', _formatNum(stats.missedUnits)),
      ]);
    } else if (tracker.checkInType == TrackerCheckInType.duration) {
      cards.addAll([
        _StatItem('Done minutes', _formatNum(stats.doneMinutes)),
        _StatItem('Missed minutes', _formatNum(stats.missedMinutes)),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Wrap(
          spacing: CompanionFormStyles.taskListChipGap,
          runSpacing: CompanionFormStyles.taskListChipGap,
          children: [
            for (final card in cards) TrackerStatCard(
              label: card.label,
              value: card.value,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TrackerWeekSuccessStrip(
          listToday: listToday,
          dayOutcomes: stats.dayOutcomes,
          thisWeekPercent: stats.thisWeekPercent,
        ),
        const SizedBox(height: 16),
        TrackerSuccessTrendChart(weeklyRates: stats.weeklySuccessRates),
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

  String _formatNum(num value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _StatItem {
  const _StatItem(this.label, this.value);

  final String label;
  final String value;
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
