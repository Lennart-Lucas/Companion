import 'package:flutter/material.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/core/ui/outcome_colors.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';

/// Compact Mon–Sun pill strip for weekly summary tracker cards.
class WeeklySummaryTrackerWeekStrip extends StatelessWidget {
  const WeeklySummaryTrackerWeekStrip({
    super.key,
    required this.weekStart,
    required this.listToday,
    required this.dayOutcomes,
  });

  final DateTime weekStart;
  final DateTime listToday;
  final Map<DateTime, TrackerDayOutcome> dayOutcomes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = taskListWeekDays(weekStart);

    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Text(
                    taskListWeekdayAbbrev(day),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _DayPill(
                    day: day,
                    listToday: listToday,
                    outcome: trackerDayOutcomeOn(dayOutcomes, day),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.listToday,
    required this.outcome,
  });

  final DateTime day;
  final DateTime listToday;
  final TrackerDayOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = taskListDayIsToday(day, now: listToday);

    Color fill;
    switch (outcome) {
      case TrackerDayOutcome.succeeded:
        fill = trackerStrengthHighColor;
      case TrackerDayOutcome.missed:
        fill = trackerStrengthLowColor;
      case TrackerDayOutcome.skipped:
        fill = scheme.onSurface.withValues(alpha: 0.2);
      case TrackerDayOutcome.pending:
      case null:
        fill = scheme.onSurface.withValues(alpha: 0.12);
    }

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
        border: isToday ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
    );
  }
}
