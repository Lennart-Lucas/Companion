import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_day_outcome_appearance.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

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

  static const _rowCount = 6;
  static const _colCount = 7;
  static const _gridGap = 8.0;
  static const _cellRadius = 14.0;
  static const _cellHeightFactor = 1.22;
  static const _minCellHeight = 52.0;
  static const _maxCellHeight = 88.0;
  static const _weekdayLabels = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
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

  static const _headerOverhead = 108.0;

  double _cellWidthFor(double width) =>
      (width - _gridGap * (_colCount - 1)) / _colCount;

  double _cellHeightFor(double width, BoxConstraints constraints) {
    final cellWidth = _cellWidthFor(width);
    var cellHeight =
        (cellWidth * _cellHeightFactor).clamp(_minCellHeight, _maxCellHeight);

    if (!constraints.hasBoundedHeight) return cellHeight;

    final maxGridHeight = constraints.maxHeight - _headerOverhead;
    if (maxGridHeight <= 0) return _minCellHeight;

    final maxByHeight =
        (maxGridHeight - _gridGap * (_rowCount - 1)) / _rowCount;
    return cellHeight.clamp(_minCellHeight, maxByHeight);
  }

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cellWidth = _cellWidthFor(width);
          final cellHeight = _cellHeightFor(width, constraints);
          final gridHeight =
              cellHeight * _rowCount + _gridGap * (_rowCount - 1);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        monthTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (onGoToCurrentMonth != null) ...[
                      _CalendarNavButton(
                        icon: Icons.calendar_today_outlined,
                        tooltip: 'Go to current month',
                        onPressed: onGoToCurrentMonth!,
                      ),
                      const SizedBox(width: 6),
                    ],
                    _CalendarNavButton(
                      icon: Icons.chevron_left,
                      tooltip: 'Previous month',
                      onPressed: onPreviousMonth,
                    ),
                    const SizedBox(width: 6),
                    _CalendarNavButton(
                      icon: Icons.chevron_right,
                      tooltip: 'Next month',
                      onPressed: onNextMonth,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  children: [
                    for (final label in _weekdayLabels)
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: gridHeight,
                child: Column(
                  children: [
                    for (var row = 0; row < _rowCount; row++) ...[
                      if (row > 0) const SizedBox(height: _gridGap),
                      Row(
                        children: [
                          for (var col = 0; col < _colCount; col++) ...[
                            if (col > 0) const SizedBox(width: _gridGap),
                            SizedBox(
                              width: cellWidth,
                              height: cellHeight,
                              child: _MonthSuccessDayCell(
                                day: gridDays[row * _colCount + col],
                                monthStart: monthStart,
                                listToday: listToday,
                                outcome: trackerDayOutcomeOn(
                                  dayOutcomes,
                                  gridDays[row * _colCount + col],
                                ),
                                onTap: _isDayTappable(
                                  gridDays[row * _colCount + col],
                                  monthStart,
                                )
                                    ? () => onDaySelected!(
                                          gridDays[row * _colCount + col],
                                        )
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _TrackerCalendarLegend(),
            ],
          );
        },
      ),
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            splashColor: scheme.onSurface.withValues(alpha: 0.08),
            highlightColor: scheme.onSurface.withValues(alpha: 0.05),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                icon,
                size: 18,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
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
    required this.outcome,
    this.onTap,
  });

  final DateTime day;
  final DateTime monthStart;
  final DateTime listToday;
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

    final appearance = TrackerDayOutcomeAppearance.resolve(
      outcome: outcome,
      scheme: scheme,
      isToday: isToday,
      isFuture: isFuture,
      inMonth: inMonth,
    );

    final hasCard = appearance.background != Colors.transparent;
    final showMarker = appearance.marker != null && (hasCard || isToday);

    final column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${day.day}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: appearance.dayNumberColor,
            fontWeight: isToday || hasCard ? FontWeight.w700 : FontWeight.w500,
            height: 1,
          ),
        ),
        if (showMarker) ...[
          const SizedBox(height: 4),
          appearance.marker!,
        ],
      ],
    );

    final content = Center(child: column);

    final decoration = BoxDecoration(
      color: appearance.background,
      borderRadius: BorderRadius.circular(
        TrackerMonthSuccessCalendar._cellRadius,
      ),
      border: appearance.border,
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: decoration,
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          TrackerMonthSuccessCalendar._cellRadius,
        ),
        child: Ink(
          decoration: decoration,
          child: SizedBox.expand(child: content),
        ),
      ),
    );
  }
}
