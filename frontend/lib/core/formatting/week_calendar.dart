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

const _monthAbbrevs = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

DateTime normalizeTaskListCalendarDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String formatTaskListDateHeader(DateTime localDay, {DateTime? now}) {
  final day = normalizeTaskListCalendarDay(localDay);
  final today = normalizeTaskListCalendarDay(now ?? DateTime.now());
  if (day == today) return 'Today';

  final weekday = _weekdayNames[day.weekday - 1];
  final month = _monthNames[day.month - 1];
  return '$weekday, ${day.day} $month ${day.year}';
}

bool taskListDayIsToday(DateTime localDay, {DateTime? now}) {
  final day = normalizeTaskListCalendarDay(localDay);
  final today = normalizeTaskListCalendarDay(now ?? DateTime.now());
  return day == today;
}

bool taskListDayIsBeforeToday(DateTime localDay, {DateTime? now}) {
  final day = normalizeTaskListCalendarDay(localDay);
  final today = normalizeTaskListCalendarDay(now ?? DateTime.now());
  return day.isBefore(today);
}

DateTime taskListWeekStart(DateTime date) {
  final day = normalizeTaskListCalendarDay(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

List<DateTime> taskListWeekDays(DateTime weekStart) {
  final start = normalizeTaskListCalendarDay(weekStart);
  return [
    for (var i = 0; i < 7; i++) start.add(Duration(days: i)),
  ];
}

String taskListWeekdayAbbrev(DateTime day) {
  final normalized = normalizeTaskListCalendarDay(day);
  return _weekdayAbbrevs[normalized.weekday - 1];
}

String formatTaskListWeekTitle(DateTime weekStart) {
  final day = normalizeTaskListCalendarDay(weekStart);
  final month = _monthNames[day.month - 1];
  return '$month ${day.year}';
}

/// Last local calendar day (Sunday) of the Monday-start week containing [weekStart].
DateTime taskListWeekEnd(DateTime weekStart) {
  return normalizeTaskListCalendarDay(weekStart).add(const Duration(days: 6));
}

/// Whether [day] is Sunday in local calendar terms.
bool taskListDayIsSunday(DateTime day) {
  return normalizeTaskListCalendarDay(day).weekday == DateTime.sunday;
}

/// Header-style Mon–Sun range, e.g. "Jul 6 – 12, 2026".
String formatWeekRangeLabelHeader(DateTime weekStart) {
  final start = normalizeTaskListCalendarDay(weekStart);
  final end = taskListWeekEnd(start);
  final startMonth = _monthAbbrevs[start.month - 1];
  final endMonth = _monthAbbrevs[end.month - 1];
  if (start.year == end.year) {
    if (start.month == end.month) {
      return '$startMonth ${start.day} – ${end.day}, ${end.year}';
    }
    return '$startMonth ${start.day} – $endMonth ${end.day}, ${end.year}';
  }
  return '$startMonth ${start.day}, ${start.year} – $endMonth ${end.day}, ${end.year}';
}

/// Human-readable Mon–Sun range, e.g. "6 Jul – 12 Jul 2026".
String formatWeekRangeLabel(DateTime weekStart) {
  final start = normalizeTaskListCalendarDay(weekStart);
  final end = taskListWeekEnd(start);
  final startMonth = _monthAbbrevs[start.month - 1];
  final endMonth = _monthAbbrevs[end.month - 1];
  if (start.year == end.year) {
    if (start.month == end.month) {
      return '${start.day} – ${end.day} $endMonth ${end.year}';
    }
    return '${start.day} $startMonth – ${end.day} $endMonth ${end.year}';
  }
  return '${start.day} $startMonth ${start.year} – ${end.day} $endMonth ${end.year}';
}

/// ISO date (`yyyy-MM-dd`) for a Monday [weekStart] route parameter.
String formatWeekStartParam(DateTime weekStart) {
  final day = normalizeTaskListCalendarDay(weekStart);
  final y = day.year.toString();
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses [formatWeekStartParam] values; returns normalized Monday midnight.
DateTime? parseWeekStartParam(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return taskListWeekStart(parsed);
}

bool taskListWeekIsCurrent(DateTime weekStart, {DateTime? now}) {
  final today = normalizeTaskListCalendarDay(now ?? DateTime.now());
  final currentWeekStart = taskListWeekStart(today);
  return normalizeTaskListCalendarDay(weekStart) == currentWeekStart;
}

DateTime taskListMonthStart(DateTime date) {
  final day = normalizeTaskListCalendarDay(date);
  return DateTime(day.year, day.month);
}

List<DateTime> taskListMonthGridDays(DateTime month) {
  final monthStart = taskListMonthStart(month);
  final gridStart = taskListWeekStart(monthStart);
  return [
    for (var i = 0; i < 42; i++) gridStart.add(Duration(days: i)),
  ];
}

bool taskListDayInMonth(DateTime day, DateTime monthStart) {
  final normalized = normalizeTaskListCalendarDay(day);
  final month = taskListMonthStart(monthStart);
  return normalized.year == month.year && normalized.month == month.month;
}

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

DateTime taskListMonthForPage(
  int page, {
  required DateTime listToday,
  int initialPage = 10000,
}) {
  final anchorMonth = taskListMonthStart(listToday);
  final offsetMonths = page - initialPage;
  return DateTime(anchorMonth.year, anchorMonth.month + offsetMonths);
}

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