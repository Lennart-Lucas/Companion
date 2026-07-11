import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/ui/outcome_colors.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
class TrackerWeekSuccessStrip extends StatelessWidget {
  const TrackerWeekSuccessStrip({
    super.key,
    required this.listToday,
    required this.dayOutcomes,
    required this.thisWeekPercent,
  });

  final DateTime listToday;
  final Map<DateTime, TrackerDayOutcome> dayOutcomes;
  final double thisWeekPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weekStart = taskListWeekStart(listToday);
    final days = taskListWeekDays(weekStart);
    final title = formatTaskListWeekTitle(weekStart);

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'This week',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(thisWeekPercent * 100).round()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: _WeekDayCell(
                    day: day,
                    listToday: listToday,
                    outcome: trackerDayOutcomeOn(dayOutcomes, day),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.day,
    required this.listToday,
    required this.outcome,
  });

  final DateTime day;
  final DateTime listToday;
  final TrackerDayOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = taskListDayIsToday(day, now: listToday);

    Color? fill;
    Widget? marker;
    switch (outcome) {
      case TrackerDayOutcome.succeeded:
        fill = trackerStrengthHighColor.withValues(alpha: 0.22);
        marker = Icon(Icons.check, size: 14, color: trackerStrengthHighColor);
      case TrackerDayOutcome.missed:
        fill = trackerStrengthLowColor.withValues(alpha: 0.18);
        marker = Icon(Icons.close, size: 14, color: trackerStrengthLowColor);
      case TrackerDayOutcome.skipped:
        fill = scheme.onSurface.withValues(alpha: 0.08);
        marker = Text(
          '—',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.45),
          ),
        );
      case TrackerDayOutcome.pending:
      case null:
        fill = scheme.surfaceContainerHigh;
    }

    return Column(
      children: [
        Text(
          taskListWeekdayAbbrev(day),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          child: marker,
        ),
        const SizedBox(height: 4),
        Text(
          '${day.day}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
