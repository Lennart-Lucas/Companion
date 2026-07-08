import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

/// Label and chip icon for a completed task (matches tracker "Done" outcome).
const String taskCompletedStatusLabel = 'Done';

IconData taskCompletedStatusChipIcon() => Icons.check_circle_outline;

Color taskCompletedStatusColor() => trackerStrengthHighColor;

/// Human-readable labels for task status / priority API values.
String taskStatusLabel(String value) => switch (value) {
      'pending' => 'Pending',
      'in_progress' => 'In progress',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => value,
    };

String taskPriorityLabel(String value) => switch (value) {
      'low' => 'Low',
      'medium' => 'Medium',
      'high' => 'High',
      'urgent' => 'Urgent',
      _ => value,
    };

String formatTaskDeadline(DateTime deadline) {
  final local = deadline.toLocal();
  final y = local.year.toString();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatTaskOccurrenceDate(DateTime date) => formatTaskDeadline(date);

/// Time or date label for task list metadata (local time when non-midnight).
String? formatTaskListTime(TaskListEntry entry) {
  final dt =
      entry.occurrenceAt ?? entry.task.plannedAt ?? entry.task.deadline;
  if (dt == null) return null;

  final local = dt.toLocal();
  if (local.hour == 0 && local.minute == 0 && local.second == 0) {
    return formatTaskDeadline(local);
  }

  final hour = local.hour;
  final minute = local.minute;
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final minuteStr = minute.toString().padLeft(2, '0');
  return '$hour12:$minuteStr $period';
}

/// Whether [formatTaskListTime] would show a clock time vs a date-only label.
bool taskListTimeShowsClock(TaskListEntry entry) {
  final dt =
      entry.occurrenceAt ?? entry.task.plannedAt ?? entry.task.deadline;
  if (dt == null) return false;
  final local = dt.toLocal();
  return local.hour != 0 || local.minute != 0 || local.second != 0;
}

/// Local calendar day for grouping a list entry (midnight local).
DateTime? taskListEntryLocalDay(TaskListEntry entry) {
  final dt = entry.displayAt ??
      entry.occurrenceAt ??
      entry.task.plannedAt ??
      entry.task.deadline;
  if (dt == null) return null;
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdayAbbrevs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Normalizes [date] to a local calendar day for comparisons.
DateTime normalizeTaskListCalendarDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Section header label for a task list day group.
String formatTaskListDateHeader(DateTime localDay, {DateTime? now}) {
  final day = normalizeTaskListCalendarDay(localDay);
  final today = normalizeTaskListCalendarDay(now ?? DateTime.now());
  if (day == today) return 'Today';

  final weekday = _weekdayNames[day.weekday - 1];
  final month = _monthNames[day.month - 1];
  return '$weekday, ${day.day} $month ${day.year}';
}

/// Whether [localDay] is the current local calendar day.
bool taskListDayIsToday(DateTime localDay, {DateTime? now}) {
  final day = normalizeTaskListCalendarDay(localDay);
  final today = normalizeTaskListCalendarDay(now ?? DateTime.now());
  return day == today;
}

/// Whether [localDay] is strictly before the current local calendar day.
bool taskListDayIsBeforeToday(DateTime localDay, {DateTime? now}) {
  final day = normalizeTaskListCalendarDay(localDay);
  final today = normalizeTaskListCalendarDay(now ?? DateTime.now());
  return day.isBefore(today);
}

/// Local Monday midnight of the week containing [date].
DateTime taskListWeekStart(DateTime date) {
  final day = normalizeTaskListCalendarDay(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Seven consecutive local calendar days from [weekStart] (Mon–Sun).
List<DateTime> taskListWeekDays(DateTime weekStart) {
  final start = normalizeTaskListCalendarDay(weekStart);
  return [
    for (var i = 0; i < 7; i++) start.add(Duration(days: i)),
  ];
}

/// Short weekday label for week strip cells (`Mon`, `Tue`, …).
String taskListWeekdayAbbrev(DateTime day) {
  final normalized = normalizeTaskListCalendarDay(day);
  return _weekdayAbbrevs[normalized.weekday - 1];
}

/// Month and year label for the week strip header (e.g. `June 2026`).
String formatTaskListWeekTitle(DateTime weekStart) {
  final day = normalizeTaskListCalendarDay(weekStart);
  final month = _monthNames[day.month - 1];
  return '$month ${day.year}';
}

/// First local calendar day of the month containing [date].
DateTime taskListMonthStart(DateTime date) {
  final day = normalizeTaskListCalendarDay(date);
  return DateTime(day.year, day.month);
}

/// Six-week Monday-first grid for [month] (includes outside-month padding days).
List<DateTime> taskListMonthGridDays(DateTime month) {
  final monthStart = taskListMonthStart(month);
  final gridStart = taskListWeekStart(monthStart);
  return [
    for (var i = 0; i < 42; i++) gridStart.add(Duration(days: i)),
  ];
}

/// Whether [day] belongs to the same month as [monthStart].
bool taskListDayInMonth(DateTime day, DateTime monthStart) {
  final normalized = normalizeTaskListCalendarDay(day);
  final month = taskListMonthStart(monthStart);
  return normalized.year == month.year && normalized.month == month.month;
}

/// PageView index for the week containing [day], anchored to [listToday].
int taskListWeekPageForDay({
  required DateTime day,
  required DateTime listToday,
  int initialPage = 10000,
}) {
  final anchorWeekStart = taskListWeekStart(listToday);
  final targetWeekStart = taskListWeekStart(day);
  final offsetWeeks = targetWeekStart.difference(anchorWeekStart).inDays ~/ 7;
  return initialPage + offsetWeeks;
}

/// Month start for a month pager page anchored to [listToday].
DateTime taskListMonthForPage(
  int page, {
  required DateTime listToday,
  int initialPage = 10000,
}) {
  final anchorMonth = taskListMonthStart(listToday);
  final offsetMonths = page - initialPage;
  return DateTime(anchorMonth.year, anchorMonth.month + offsetMonths);
}

/// PageView index for the month containing [day], anchored to [listToday].
int taskListMonthPageForDay({
  required DateTime day,
  required DateTime listToday,
  int initialPage = 10000,
}) {
  final anchorMonth = taskListMonthStart(listToday);
  final targetMonth = taskListMonthStart(day);
  final offsetMonths =
      (targetMonth.year - anchorMonth.year) * 12 +
      (targetMonth.month - anchorMonth.month);
  return initialPage + offsetMonths;
}
