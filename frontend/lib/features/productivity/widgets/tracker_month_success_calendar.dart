import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';
import 'package:frontend/features/productivity/widgets/tracker_day_outcome_appearance.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

class TrackerMonthSuccessCalendar extends StatelessWidget {
  const TrackerMonthSuccessCalendar({
    super.key,
    required this.displayedMonth,
    required this.listToday,
    required this.dayOutcomes,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onGoToCurrentMonth,
    this.onDaySelected,
    this.trackerStartDate,
    this.trackerEndDate,
  });

  static const panelHeight = 320.0;
  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  final DateTime displayedMonth;
  final DateTime listToday;
  final Map<DateTime, TrackerDayOutcome> dayOutcomes;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onGoToCurrentMonth;
  final ValueChanged<DateTime>? onDaySelected;
  final DateTime? trackerStartDate;
  final DateTime? trackerEndDate;

  bool _isDayTappable(DateTime day, DateTime monthStart) {
    if (onDaySelected == null) return false;
    if (!taskListDayInMonth(day, monthStart)) return false;

    final normalized = normalizeTaskListCalendarDay(day);
    final today = normalizeTaskListCalendarDay(listToday);
    if (normalized.isAfter(today)) return false;

    final start = trackerStartDate;
    if (start != null &&
        normalized.isBefore(normalizeTaskListCalendarDay(start))) {
      return false;
    }
    final end = trackerEndDate;
    if (end != null && normalized.isAfter(normalizeTaskListCalendarDay(end))) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final monthStart = taskListMonthStart(displayedMonth);
    final gridDays = taskListMonthGridDays(displayedMonth);
    final monthTitle = formatTaskListWeekTitle(monthStart);

    return TrackerRowPanel(
      child: SizedBox(
        height: panelHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                    onPressed: onPreviousMonth,
                  ),
                  Expanded(
                    child: Text(
                      monthTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onGoToCurrentMonth != null) ...[
                    IconButton(
                      icon: Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: scheme.onSurface,
                      ),
                      tooltip: 'Go to current month',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: onGoToCurrentMonth,
                    ),
                    const SizedBox(width: 12),
                  ],
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                    onPressed: onNextMonth,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  for (final label in _weekdayLabels)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const rowCount = 6;
                  const colCount = 7;
                  final cellHeight = constraints.maxHeight / rowCount;
                  final cellWidth = constraints.maxWidth / colCount;

                  return Column(
                    children: [
                      for (var row = 0; row < rowCount; row++)
                        SizedBox(
                          height: cellHeight,
                          child: Row(
                            children: [
                              for (var col = 0; col < colCount; col++)
                                Expanded(
                                  child: _MonthSuccessDayCell(
                                    day: gridDays[row * colCount + col],
                                    monthStart: monthStart,
                                    listToday: listToday,
                                    cellHeight: cellHeight,
                                    cellWidth: cellWidth,
                                    outcome: trackerDayOutcomeOn(
                                      dayOutcomes,
                                      gridDays[row * colCount + col],
                                    ),
                                    onTap: _isDayTappable(
                                      gridDays[row * colCount + col],
                                      monthStart,
                                    )
                                        ? () => onDaySelected!(
                                              gridDays[row * colCount + col],
                                            )
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const _TrackerCalendarLegend(),
          ],
        ),
      ),
    );
  }
}

class _TrackerCalendarLegend extends StatelessWidget {
  const _TrackerCalendarLegend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendItem(
          label: 'Done',
          appearance: TrackerDayOutcomeAppearance.resolve(
            outcome: TrackerDayOutcome.succeeded,
            scheme: scheme,
            isToday: false,
            isFuture: false,
            inMonth: true,
          ),
        ),
        _LegendItem(
          label: 'Missed',
          appearance: TrackerDayOutcomeAppearance.resolve(
            outcome: TrackerDayOutcome.missed,
            scheme: scheme,
            isToday: false,
            isFuture: false,
            inMonth: true,
          ),
        ),
        _LegendItem(
          label: 'Skipped',
          appearance: TrackerDayOutcomeAppearance.resolve(
            outcome: TrackerDayOutcome.skipped,
            scheme: scheme,
            isToday: false,
            isFuture: false,
            inMonth: true,
          ),
        ),
        _LegendItem(
          label: 'Pending',
          appearance: TrackerDayOutcomeAppearance.resolve(
            outcome: TrackerDayOutcome.pending,
            scheme: scheme,
            isToday: false,
            isFuture: false,
            inMonth: true,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.appearance,
  });

  final String label;
  final TrackerDayOutcomeAppearance appearance;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        appearance.legendPreview(),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.75),
              ),
        ),
      ],
    );
  }
}

class _MonthSuccessDayCell extends StatelessWidget {
  const _MonthSuccessDayCell({
    required this.day,
    required this.monthStart,
    required this.listToday,
    required this.cellHeight,
    required this.cellWidth,
    required this.outcome,
    this.onTap,
  });

  final DateTime day;
  final DateTime monthStart;
  final DateTime listToday;
  final double cellHeight;
  final double cellWidth;
  final TrackerDayOutcome? outcome;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inMonth = taskListDayInMonth(day, monthStart);
    final isToday = taskListDayIsToday(day, now: listToday);
    final normalized = normalizeTaskListCalendarDay(day);
    final isFuture =
        normalized.isAfter(normalizeTaskListCalendarDay(listToday));

    final marginH = cellWidth * 0.06;
    final marginV = cellHeight * 0.08;

    final appearance = TrackerDayOutcomeAppearance.resolve(
      outcome: outcome,
      scheme: scheme,
      isToday: isToday,
      isFuture: isFuture,
      inMonth: inMonth,
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${day.day}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: appearance.dayNumberColor,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            height: 1,
          ),
        ),
        if (appearance.marker != null && inMonth) ...[
          const SizedBox(height: 1),
          appearance.marker!,
        ],
      ],
    );

    final content = appearance.marker != null && inMonth
        ? FittedBox(fit: BoxFit.scaleDown, child: column)
        : Center(child: column);

    final decoration = BoxDecoration(
      color: appearance.background,
      borderRadius: BorderRadius.circular(10),
      border: appearance.border,
    );

    if (onTap == null) {
      return SizedBox(
        height: cellHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: marginH, vertical: marginV),
          child: DecoratedBox(
            decoration: decoration,
            child: content,
          ),
        ),
      );
    }

    return SizedBox(
      height: cellHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: marginH, vertical: marginV),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              decoration: decoration,
              child: SizedBox.expand(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
