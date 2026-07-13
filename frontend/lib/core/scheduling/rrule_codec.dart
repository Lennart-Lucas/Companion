import 'package:rrule/rrule.dart';

/// Friendly-builder pattern ids (codec only; not stored in DB).
abstract final class ScheduleRepeatType {
  static const none = 'none';
  static const weekdays = 'weekdays';
  static const everyNDays = 'every_n_days';
  static const everyNWeeks = 'every_n_weeks';
  static const everyNMonths = 'every_n_months';
  static const everyNYears = 'every_n_years';
  static const specificDates = 'specific_dates';
  static const monthDays = 'month_days';
  static const quota = 'quota';
}

const _isoToIcal = {
  1: 'MO',
  2: 'TU',
  3: 'WE',
  4: 'TH',
  5: 'FR',
  6: 'SA',
  7: 'SU',
};

class ScheduleRrulePattern {
  const ScheduleRrulePattern({
    required this.pattern,
    this.interval = 1,
    this.weekdays = const [],
    this.monthDays = const [],
  });

  final String pattern;
  final int interval;
  final List<int> weekdays;
  final List<int> monthDays;
}

bool scheduleIsRecurring(
  String? rrule,
  List<DateTime> rdates, {
  int? quotaTimes,
  int? quotaPeriodWeeks,
}) {
  if (quotaTimes != null && quotaPeriodWeeks != null) return true;
  if (rrule != null && rrule.isNotEmpty) return true;
  return rdates.isNotEmpty;
}

String? patternToRrule({
  required String pattern,
  int interval = 1,
  List<int> weekdays = const [],
  List<int> monthDays = const [],
  DateTime? until,
}) {
  switch (pattern) {
    case ScheduleRepeatType.none:
    case ScheduleRepeatType.specificDates:
    case ScheduleRepeatType.quota:
      return null;
    case ScheduleRepeatType.everyNDays:
      return _withUntil('FREQ=DAILY;INTERVAL=$interval', until);
    case ScheduleRepeatType.everyNWeeks:
      return _withUntil('FREQ=WEEKLY;INTERVAL=$interval', until);
    case ScheduleRepeatType.weekdays:
      if (weekdays.isEmpty) {
        throw ArgumentError('weekdays required');
      }
      final byday = weekdays.map((d) => _isoToIcal[d]!).join(',');
      return _withUntil('FREQ=WEEKLY;INTERVAL=$interval;BYDAY=$byday', until);
    case ScheduleRepeatType.everyNMonths:
      return _withUntil('FREQ=MONTHLY;INTERVAL=$interval', until);
    case ScheduleRepeatType.everyNYears:
      return _withUntil('FREQ=YEARLY;INTERVAL=$interval', until);
    case ScheduleRepeatType.monthDays:
      if (monthDays.isEmpty) {
        throw ArgumentError('monthDays required');
      }
      final days = monthDays.join(',');
      return _withUntil('FREQ=MONTHLY;INTERVAL=$interval;BYMONTHDAY=$days', until);
    default:
      throw ArgumentError('Unknown pattern: $pattern');
  }
}

String _withUntil(String rrule, DateTime? until) {
  if (until == null) return rrule;
  final utc = until.toUtc();
  final stamp =
      '${utc.year.toString().padLeft(4, '0')}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}T${utc.hour.toString().padLeft(2, '0')}${utc.minute.toString().padLeft(2, '0')}${utc.second.toString().padLeft(2, '0')}Z';
  return '$rrule;UNTIL=$stamp';
}

ScheduleRrulePattern rruleToPattern(String rrule) {
  final rule = RecurrenceRule.fromString('RRULE:$rrule');
  final interval = rule.interval ?? 1;
  final hasByDay = rrule.toUpperCase().contains('BYDAY=');
  final hasByMonthDay = rrule.toUpperCase().contains('BYMONTHDAY=');

  switch (rule.frequency) {
    case Frequency.daily:
      return ScheduleRrulePattern(
        pattern: ScheduleRepeatType.everyNDays,
        interval: interval,
      );
    case Frequency.weekly:
      if (rule.byWeekDays.isNotEmpty && hasByDay) {
        final weekdays = rule.byWeekDays.map((d) => d.day).toSet().toList()
          ..sort();
        return ScheduleRrulePattern(
          pattern: ScheduleRepeatType.weekdays,
          interval: interval,
          weekdays: weekdays,
        );
      }
      return ScheduleRrulePattern(
        pattern: ScheduleRepeatType.everyNWeeks,
        interval: interval,
      );
    case Frequency.monthly:
      if (rule.byMonthDays.isNotEmpty && hasByMonthDay) {
        final days = rule.byMonthDays.map((d) => d).toList()..sort();
        return ScheduleRrulePattern(
          pattern: ScheduleRepeatType.monthDays,
          interval: interval,
          monthDays: days,
        );
      }
      return ScheduleRrulePattern(
        pattern: ScheduleRepeatType.everyNMonths,
        interval: interval,
      );
    case Frequency.yearly:
      return ScheduleRrulePattern(
        pattern: ScheduleRepeatType.everyNYears,
        interval: interval,
      );
    default:
      throw ArgumentError('Unsupported RRULE: $rrule');
  }
}

String scheduleSummaryFromApi(Map<String, dynamic> schedule) {
  final rrule = schedule['rrule']?.toString();
  if (rrule != null && rrule.isNotEmpty) {
    try {
      final pattern = rruleToPattern(rrule);
      final label = _patternLabel(pattern.pattern);
      return label;
    } catch (_) {
      return 'Repeating';
    }
  }
  final rdates = schedule['rdates'];
  if (rdates is List && rdates.isNotEmpty) {
    return 'Specific dates';
  }
  return 'One-off';
}

String _patternLabel(String pattern) => switch (pattern) {
      ScheduleRepeatType.weekdays => 'Weekly on selected days',
      ScheduleRepeatType.everyNDays => 'Every N days',
      ScheduleRepeatType.everyNWeeks => 'Every N weeks',
      ScheduleRepeatType.everyNMonths => 'Every N months',
      ScheduleRepeatType.everyNYears => 'Every N years',
      ScheduleRepeatType.specificDates => 'Specific dates',
      ScheduleRepeatType.monthDays => 'Days of month',
      _ => 'One-off',
    };
