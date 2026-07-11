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