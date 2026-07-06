import 'package:frontend/features/productivity/models/task_schedule.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

class QuotaPeriod {
  const QuotaPeriod({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

DateTime _localDay(DateTime date) => normalizeTaskListCalendarDay(date.toLocal());

DateTime isoWeekStart(DateTime day) => taskListWeekStart(day);

int _isoWeekNumber(DateTime day) {
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final yearStart = DateTime(thursday.year, 1, 1);
  return 1 + ((thursday.difference(yearStart).inDays) / 7).floor();
}

QuotaPeriod periodForDate(
  DateTime day, {
  required int interval,
  required String unit,
}) {
  final normalized = _localDay(day);
  if (interval < 1) {
    throw ArgumentError('interval must be >= 1');
  }

  if (unit == QuotaPeriodUnit.weeks) {
    final year = normalized.year;
    final week = _isoWeekNumber(normalized);
    final blockIndex = (week - 1) ~/ interval;
    final firstWeek = blockIndex * interval + 1;
    final periodStart = isoWeekStart(
      DateTime(year, 1, 4).add(Duration(days: (firstWeek - 1) * 7)),
    );
    final periodEnd = periodStart.add(Duration(days: interval * 7 - 1));
    return QuotaPeriod(start: periodStart, end: periodEnd);
  }

  if (unit == QuotaPeriodUnit.months) {
    final blockIndex = (normalized.month - 1) ~/ interval;
    final startMonth = blockIndex * interval + 1;
    final periodStart = DateTime(normalized.year, startMonth);
    final endMonth = startMonth + interval - 1;
    final periodEnd = DateTime(normalized.year, endMonth + 1, 0);
    return QuotaPeriod(start: periodStart, end: periodEnd);
  }

  if (unit == QuotaPeriodUnit.years) {
    final blockIndex = (normalized.year - 1) ~/ interval;
    final startYear = blockIndex * interval + 1;
    final endYear = startYear + interval - 1;
    return QuotaPeriod(
      start: DateTime(startYear),
      end: DateTime(endYear, 12, 31),
    );
  }

  throw ArgumentError('unsupported period unit: $unit');
}
