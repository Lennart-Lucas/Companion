import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

/// Single-month grid for the task list month pager.
class TaskListMonthCalendar extends StatelessWidget {
  const TaskListMonthCalendar({
    super.key,
    required this.displayedMonth,
    required this.listToday,
    required this.selectedDay,
    required this.onDaySelected,
    this.onCollapse,
    this.showCollapseControl = true,
    this.chevronTurns = 0.5,
  });

  static const panelHeight = 280.0;
  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final DateTime displayedMonth;
  final DateTime listToday;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback? onCollapse;
  final bool showCollapseControl;
  final double chevronTurns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final monthStart = taskListMonthStart(displayedMonth);
    final gridDays = taskListMonthGridDays(displayedMonth);
    final monthTitle = formatTaskListWeekTitle(monthStart);

    return SizedBox(
      height: panelHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: showCollapseControl
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: onCollapse,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.rotate(
                                angle: chevronTurns * pi * 2,
                                child: Icon(
                                  Icons.expand_more,
                                  size: 20,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                monthTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          monthTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                  final cellSize = cellHeight < cellWidth ? cellHeight : cellWidth;

                  return Column(
                    children: [
                      for (var row = 0; row < rowCount; row++)
                        SizedBox(
                          height: cellHeight,
                          child: Row(
                            children: [
                              for (var col = 0; col < colCount; col++)
                                Expanded(
                                  child: _MonthDayCell(
                                    day: gridDays[row * colCount + col],
                                    monthStart: monthStart,
                                    listToday: listToday,
                                    selectedDay: selectedDay,
                                    cellSize: cellSize,
                                    onTap: onDaySelected,
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
          ],
        ),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.monthStart,
    required this.listToday,
    required this.selectedDay,
    required this.cellSize,
    required this.onTap,
  });

  final DateTime day;
  final DateTime monthStart;
  final DateTime listToday;
  final DateTime? selectedDay;
  final double cellSize;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = scheme.primary;
    final normalized = normalizeTaskListCalendarDay(day);
    final inMonth = taskListDayInMonth(day, monthStart);
    final isToday = taskListDayIsToday(day, now: listToday);
    final isSelected = selectedDay != null &&
        normalizeTaskListCalendarDay(selectedDay!) == normalized;

    final dayColor = isSelected
        ? scheme.onPrimary
        : isToday
            ? primary
            : inMonth
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(normalized),
        customBorder: const CircleBorder(),
        child: Center(
          child: SizedBox(
            width: cellSize.clamp(28.0, 40.0),
            height: cellSize.clamp(28.0, 40.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isSelected ? primary : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: primary, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${normalized.day}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: dayColor,
                    fontWeight:
                        isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
