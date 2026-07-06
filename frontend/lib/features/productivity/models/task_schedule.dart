import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/scheduling/rrule_codec.dart';
import 'package:timezone/timezone.dart' as tz;

/// Backend-aligned repeat types for task schedules.
abstract final class TaskRepeatType {
  static const none = 'none';
  static const weekdays = 'weekdays';
  static const everyNDays = 'every_n_days';
  static const everyNWeeks = 'every_n_weeks';
  static const everyNMonths = 'every_n_months';
  static const everyNYears = 'every_n_years';
  static const specificDates = 'specific_dates';
  static const monthDays = 'month_days';
  static const timesPerWeek = 'times_per_week';
  static const timesPerMonth = 'times_per_month';
  static const timesPerYear = 'times_per_year';

  static const all = [
    none,
    weekdays,
    everyNDays,
    everyNWeeks,
    everyNMonths,
    everyNYears,
    specificDates,
    monthDays,
    timesPerWeek,
    timesPerMonth,
    timesPerYear,
  ];

  static const quotaRepeatTypes = [
    timesPerWeek,
    timesPerMonth,
    timesPerYear,
  ];

  static String labelFor(String value) => switch (value) {
        none => 'Does not repeat',
        weekdays => 'Weekly on selected days',
        everyNDays => 'Every N days',
        everyNWeeks => 'Every N weeks',
        everyNMonths => 'Every N months',
        everyNYears => 'Every N years',
        specificDates => 'Specific dates',
        monthDays => 'Days of month',
        timesPerWeek => 'Times per week',
        timesPerMonth => 'Times per month',
        timesPerYear => 'Times per year',
        _ => value,
      };

  static bool needsInterval(String type) =>
      type == weekdays ||
      type == everyNDays ||
      type == everyNWeeks ||
      type == everyNMonths ||
      type == everyNYears ||
      type == monthDays;

  static bool isQuotaRepeatType(String type) =>
      type == timesPerWeek || type == timesPerMonth || type == timesPerYear;

  static String? quotaUnitForRepeatType(String type) => switch (type) {
        timesPerWeek => QuotaPeriodUnit.weeks,
        timesPerMonth => QuotaPeriodUnit.months,
        timesPerYear => QuotaPeriodUnit.years,
        _ => null,
      };

  static String repeatTypeForQuotaUnit(String? unit) => switch (unit) {
        QuotaPeriodUnit.months => timesPerMonth,
        QuotaPeriodUnit.years => timesPerYear,
        _ => timesPerWeek,
      };

  /// Unit label for the interval field (e.g. "day", "weeks").
  static String intervalUnitLabel(String type, {required int interval}) {
    final plural = interval != 1;
    return switch (type) {
      everyNDays => plural ? 'days' : 'day',
      everyNWeeks || weekdays => plural ? 'weeks' : 'week',
      everyNMonths || monthDays => plural ? 'months' : 'month',
      everyNYears => plural ? 'years' : 'year',
      _ => '',
    };
  }

  /// Full interval field title (e.g. "Every 2 years").
  static String intervalFieldLabel(String type, {required int interval}) {
    final unit = intervalUnitLabel(type, interval: interval);
    if (unit.isEmpty) return 'Every';
    return 'Every $interval $unit';
  }
}

/// Schedule mode for the task form (mutually exclusive payloads).
abstract final class TaskScheduleMode {
  static const off = 'off';
  static const oneOff = 'one_off';
  static const repeating = 'repeating';
  static const link = 'link';

  static const all = [off, oneOff, repeating, link];

  static String labelFor(String value) => switch (value) {
        off => 'No schedule',
        oneOff => 'One-off',
        repeating => 'Repeating',
        link => 'Link existing',
        _ => value,
      };

  static bool usesTaskDates(String mode) =>
      mode == off || mode == oneOff;
}

/// Form keys for schedule fields on the task form.
abstract final class TaskScheduleFormKeys {
  static const scheduleMode = 'schedule_mode';
  static const repeatEnabled = 'repeat_enabled';
  static const repeatType = 'repeat_type';
  static const anchor = 'schedule_anchor';
  static const startDate = 'schedule_start_date';
  static const endDate = 'schedule_end_date';
  static const timezone = 'schedule_timezone';
  static const interval = 'schedule_interval';
  static const weekdays = 'schedule_weekdays';
  static const monthDays = 'schedule_month_days';
  static const specificDates = 'schedule_specific_dates';
  static const exclusions = 'schedule_exclusions';
  static const existingScheduleId = 'existing_schedule_id';
  static const originalScheduleId = 'original_schedule_id';
  static const quotaTimes = 'quota_times';
  static const quotaPeriodUnit = 'quota_period_unit';
}

abstract final class QuotaPeriodUnit {
  static const weeks = 'weeks';
  static const months = 'months';
  static const years = 'years';

  static const all = [weeks, months, years];

  static String labelFor(String value) => switch (value) {
        weeks => 'weeks',
        months => 'months',
        years => 'years',
        _ => value,
      };
}

abstract final class CheckInMode {
  static const fixedSchedule = 'fixed_schedule';
  static const timesPerPeriod = 'times_per_period';
}

/// Reads/writes schedule slice of Anvil form values.
class TaskScheduleFormValues {
  const TaskScheduleFormValues({
    required this.mode,
    required this.repeatType,
    this.anchor,
    this.startDate,
    this.endDate,
    this.timezone = 'UTC',
    this.interval = 1,
    this.weekdays = const [],
    this.monthDays = const [],
    this.specificDates = const [],
    this.exclusions = const [],
    this.existingScheduleId,
  });

  final String mode;
  final String repeatType;
  final DateTime? anchor;
  final DateTime? startDate;
  final DateTime? endDate;
  final String timezone;
  final int interval;
  final List<int> weekdays;
  final List<int> monthDays;
  final List<DateTime> specificDates;
  final List<DateTime> exclusions;
  final String? existingScheduleId;

  bool get repeatEnabled => mode == TaskScheduleMode.repeating;

  /// Merges entity + schedule form values for trackers/goals (anchor-only date field).
  static Map<String, dynamic> mergeAnchorOnlyScheduleFormValues({
    required Map<String, dynamic> entityValues,
    required Map<String, dynamic> scheduleFormValues,
    required String existingScheduleId,
  }) {
    final merged = <String, dynamic>{
      ...scheduleFormValues,
      ...entityValues,
      TaskScheduleFormKeys.repeatEnabled: true,
      'existing_schedule_id': existingScheduleId,
    };
    merged.remove(TaskScheduleFormKeys.startDate);
    return merged;
  }

  static String modeFrom(Map<String, dynamic> values) {
    final explicit = values[TaskScheduleFormKeys.scheduleMode]?.toString();
    if (explicit != null &&
        explicit.isNotEmpty &&
        TaskScheduleMode.all.contains(explicit)) {
      return explicit;
    }
    if (values[TaskScheduleFormKeys.repeatEnabled] == true) {
      return TaskScheduleMode.repeating;
    }
    return TaskScheduleMode.off;
  }

  static Map<String, dynamic> defaultCreateValues({String timezone = 'UTC'}) {
    final today = defaultStartDate();
    return {
      TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.off,
      TaskScheduleFormKeys.repeatEnabled: false,
      TaskScheduleFormKeys.repeatType: TaskRepeatType.everyNDays,
      TaskScheduleFormKeys.anchor: today,
      TaskScheduleFormKeys.startDate: today,
      TaskScheduleFormKeys.endDate: null,
      TaskScheduleFormKeys.timezone: timezone,
      TaskScheduleFormKeys.interval: 1,
      TaskScheduleFormKeys.weekdays: <int>[],
      TaskScheduleFormKeys.monthDays: <int>[],
      TaskScheduleFormKeys.specificDates: <DateTime>[],
      TaskScheduleFormKeys.exclusions: <DateTime>[],
      TaskScheduleFormKeys.existingScheduleId: null,
    };
  }

  factory TaskScheduleFormValues.fromFormMap(Map<String, dynamic> values) {
    final mode = modeFrom(values);
    final linkedId = values[TaskScheduleFormKeys.existingScheduleId]
        ?.toString()
        .trim();
    return TaskScheduleFormValues(
      mode: mode,
      repeatType: values[TaskScheduleFormKeys.repeatType]?.toString() ??
          TaskRepeatType.everyNDays,
      anchor: _anchorFromValue(values[TaskScheduleFormKeys.anchor]),
      startDate: _anchorFromValue(values[TaskScheduleFormKeys.startDate]),
      endDate: _anchorFromValue(values[TaskScheduleFormKeys.endDate]),
      timezone: (values[TaskScheduleFormKeys.timezone]?.toString() ?? 'UTC')
          .trim(),
      interval: _intFromValue(values[TaskScheduleFormKeys.interval], fallback: 1),
      weekdays: _intListFromValue(values[TaskScheduleFormKeys.weekdays]),
      monthDays: _intListFromValue(values[TaskScheduleFormKeys.monthDays]),
      specificDates:
          _dateListFromValue(values[TaskScheduleFormKeys.specificDates]),
      exclusions: _dateListFromValue(values[TaskScheduleFormKeys.exclusions]),
      existingScheduleId:
          linkedId != null && linkedId.isNotEmpty ? linkedId : null,
    );
  }

  factory TaskScheduleFormValues.fromScheduleResponse(
    Map<String, dynamic> json,
  ) {
    final data = _unwrap(json);
    final rrule = data['rrule']?.toString();
    final rdates = _specificDatesFromResponse(data['rdates'] ?? data['specific_dates']);
    String repeatType;
    int interval = 1;
    List<int> weekdays = [];
    List<int> monthDays = [];
    String mode;

    if (rrule != null && rrule.isNotEmpty) {
      final decoded = rruleToPattern(rrule);
      repeatType = decoded.pattern;
      interval = decoded.interval;
      weekdays = decoded.weekdays;
      monthDays = decoded.monthDays;
      mode = TaskScheduleMode.repeating;
    } else if (rdates.isNotEmpty) {
      repeatType = TaskRepeatType.specificDates;
      mode = TaskScheduleMode.repeating;
    } else {
      repeatType = TaskRepeatType.none;
      mode = TaskScheduleMode.oneOff;
    }

    final timezone = data['timezone']?.toString() ?? 'UTC';

    return TaskScheduleFormValues(
      mode: mode,
      repeatType: repeatType,
      anchor: TaskScheduleFormValues.calendarDayFromScheduleInstant(
        data['dtstart'] ?? data['anchor_at'],
        timezone,
      ),
      startDate: TaskScheduleFormValues.calendarDayFromScheduleInstant(
            data['start_date'],
            timezone,
          ) ??
          TaskScheduleFormValues.calendarDayFromScheduleInstant(
            data['dtstart'] ?? data['anchor_at'],
            timezone,
          ),
      endDate: TaskScheduleFormValues.calendarDayFromScheduleInstant(
        data['end_date'],
        timezone,
      ),
      timezone: timezone,
      interval: interval,
      weekdays: weekdays,
      monthDays: monthDays,
      specificDates: rdates,
      exclusions: _exclusionsFromResponse(data['exdates'] ?? data['exclusions']),
    );
  }

  Map<String, dynamic> toFormMap() => {
        TaskScheduleFormKeys.scheduleMode: mode,
        TaskScheduleFormKeys.repeatEnabled: repeatEnabled,
        TaskScheduleFormKeys.repeatType: repeatType,
        TaskScheduleFormKeys.anchor: anchor,
        TaskScheduleFormKeys.startDate: startDate,
        TaskScheduleFormKeys.endDate: endDate,
        TaskScheduleFormKeys.timezone: timezone,
        TaskScheduleFormKeys.interval: interval,
        TaskScheduleFormKeys.weekdays: List<int>.from(weekdays),
        TaskScheduleFormKeys.monthDays: List<int>.from(monthDays),
        TaskScheduleFormKeys.specificDates:
            specificDates.map((d) => DateTime(d.year, d.month, d.day)).toList(),
        TaskScheduleFormKeys.exclusions:
            exclusions.map((d) => DateTime(d.year, d.month, d.day)).toList(),
        if (existingScheduleId != null)
          TaskScheduleFormKeys.existingScheduleId: existingScheduleId,
      };

  /// Resolves the schedule anchor from start date, legacy anchor field, or fallback.
  DateTime? resolvedAnchor({DateTime? fallbackAnchor}) =>
      startDate ?? anchor ?? fallbackAnchor;

  /// Trackers and goals only expose [anchor] in the form; prefer it over a stale
  /// hidden [startDate] left over from schedule hydration.
  DateTime? resolvedAnchorFromAnchorField({DateTime? fallbackAnchor}) =>
      anchor ?? startDate ?? fallbackAnchor;

  /// Local calendar date used as the default schedule start.
  static DateTime defaultStartDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Inline `schedule` for one-off tasks (`repeat_type: none`).
  Map<String, dynamic>? oneOffScheduleFromDeadline(DateTime? deadline) {
    if (deadline == null) return null;
    return {
      'dtstart': deadline.toUtc().toIso8601String(),
      'timezone': timezone,
    };
  }

  /// Inline `schedule` object for create/update, or null when not applicable.
  Map<String, dynamic>? toScheduleCreateJson({
    DateTime? fallbackAnchor,
    bool preferAnchorField = false,
  }) {
    if (mode != TaskScheduleMode.repeating) return null;

    final anchorDate = preferAnchorField
        ? resolvedAnchorFromAnchorField(fallbackAnchor: fallbackAnchor)
        : resolvedAnchor(fallbackAnchor: fallbackAnchor);
    if (anchorDate == null) return null;

    final anchor = _dateOnly(fallbackAnchor ?? anchorDate);
    final dtstart = _dtstartAtScheduleMidnight(anchor, timezone);
    final rrule = patternToRrule(
      pattern: repeatType,
      interval: interval,
      weekdays: weekdays,
      monthDays: monthDays,
      until: endDate,
    );

    final effectiveRrule = TaskRepeatType.isQuotaRepeatType(repeatType)
        ? 'FREQ=YEARLY;INTERVAL=1'
        : rrule;

    final map = <String, dynamic>{
      'dtstart': dtstart.toIso8601String(),
      'timezone': timezone,
    };

    if (effectiveRrule != null) {
      map['rrule'] = effectiveRrule;
    }

    if (repeatType == TaskRepeatType.specificDates && specificDates.isNotEmpty) {
      map['rdates'] = specificDates
          .map((d) => _dateOnly(d).toIso8601String().split('T').first)
          .toList();
    }

    if (preferAnchorField || startDate != null) {
      map['start_date'] =
          _dtstartAtScheduleMidnight(_dateOnly(anchorDate), timezone)
              .toIso8601String();
    }
    if (endDate != null && effectiveRrule == null) {
      map['end_date'] =
          _dtstartAtScheduleMidnight(_dateOnly(endDate!), timezone)
              .toIso8601String();
    }

    return map;
  }

  /// Validates schedule when recurrence is required (e.g. trackers).
  static String? validateRequired(Map<String, dynamic> values) {
    return validate({
      ...values,
      TaskScheduleFormKeys.repeatEnabled: true,
    });
  }

  /// Validates schedule fields for the current mode.
  static String? validate(
    Map<String, dynamic> values, {
    DateTime? fallbackAnchor,
  }) {
    final mode = modeFrom(values);
    if (mode == TaskScheduleMode.off) return null;

    if (mode == TaskScheduleMode.oneOff) {
      final deadline = values['deadline'];
      if (deadline is! DateTime) {
        return 'Deadline is required for one-off scheduled tasks';
      }
      final tz =
          (values[TaskScheduleFormKeys.timezone]?.toString() ?? 'UTC').trim();
      if (tz.isEmpty) return 'Timezone is required';
      return null;
    }

    if (mode == TaskScheduleMode.link) {
      final linked = values[TaskScheduleFormKeys.existingScheduleId]
          ?.toString()
          .trim();
      if (linked == null || linked.isEmpty) {
        return 'Select an existing schedule';
      }
      return null;
    }

    final schedule = TaskScheduleFormValues.fromFormMap(values);

    if (!TaskRepeatType.all.contains(schedule.repeatType)) {
      return 'Invalid repeat type';
    }
    if (schedule.repeatType == TaskRepeatType.none) {
      return 'Choose a repeat pattern';
    }
    if (schedule.resolvedAnchor(fallbackAnchor: fallbackAnchor) == null) {
      return 'Start date is required for repeating tasks';
    }
    if (schedule.timezone.isEmpty) {
      return 'Timezone is required';
    }

    if (schedule.startDate != null &&
        schedule.endDate != null &&
        !schedule.endDate!.isAfter(schedule.startDate!)) {
      return 'End date must be after start date';
    }

    if (TaskRepeatType.needsInterval(schedule.repeatType)) {
      if (schedule.interval < 1) {
        return 'Interval must be at least 1';
      }
    }

    if (schedule.repeatType == TaskRepeatType.weekdays) {
      if (schedule.weekdays.isEmpty) {
        return 'Select at least one weekday';
      }
      for (final d in schedule.weekdays) {
        if (d < 1 || d > 7) {
          return 'Weekdays must be between 1 (Mon) and 7 (Sun)';
        }
      }
    }

    if (schedule.repeatType == TaskRepeatType.monthDays) {
      if (schedule.monthDays.isEmpty) {
        return 'Select at least one day of the month';
      }
      for (final d in schedule.monthDays) {
        if (d < 1 || d > 31) {
          return 'Days of month must be between 1 and 31';
        }
      }
    }

    if (TaskRepeatType.isQuotaRepeatType(schedule.repeatType)) {
      final times = _intFromValue(values[TaskScheduleFormKeys.quotaTimes], fallback: 0);
      if (times < 1) {
        return 'Times must be at least 1';
      }
    }

    if (schedule.repeatType == TaskRepeatType.specificDates) {
      if (schedule.specificDates.isEmpty) {
        return 'Add at least one specific date';
      }
    }

    return null;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      return {...nested, if (json['id'] != null) 'id': json['id']};
    }
    if (nested is Map) {
      return {
        ...Map<String, dynamic>.from(nested),
        if (json['id'] != null) 'id': json['id'],
      };
    }
    return json;
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static DateTime? _anchorFromValue(dynamic value) {
    final parsed = _dateTimeFromValue(value);
    return parsed != null ? _dateOnly(parsed) : null;
  }

  static int _intFromValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static List<int> _intListFromValue(dynamic value) {
    if (value == null) return [];
    if (value is List<int>) return List<int>.from(value);
    if (value is List) {
      return value
          .map((e) => e is int ? e : int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    }
    return [];
  }

  static List<DateTime> _dateListFromValue(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.map(_dateTimeFromValue).whereType<DateTime>().toList();
  }

  static List<DateTime> _specificDatesFromResponse(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    final dates = <DateTime>[];
    for (final item in value) {
      if (item is Map) {
        final raw = item['occurrence_date'] ?? item['date'];
        final parsed = _dateTimeFromValue(raw);
        if (parsed != null) dates.add(_dateOnly(parsed));
      } else {
        final parsed = _dateTimeFromValue(item);
        if (parsed != null) dates.add(_dateOnly(parsed));
      }
    }
    return dates;
  }

  static List<DateTime> _exclusionsFromResponse(dynamic value) {
    if (value is! List) return [];
    final dates = <DateTime>[];
    for (final item in value) {
      if (item is Map) {
        final raw = item['excluded_date'] ?? item['date'];
        final parsed = _dateTimeFromValue(raw);
        if (parsed != null) dates.add(_dateOnly(parsed));
      } else {
        final parsed = _dateTimeFromValue(item);
        if (parsed != null) dates.add(_dateOnly(parsed));
      }
    }
    return dates;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Midnight on [day] in [timezone], returned as UTC (schedule dtstart).
  static DateTime dtstartAtScheduleMidnight(DateTime day, String timezone) {
    final normalized = _dateOnly(day);
    try {
      final location = tz.getLocation(timezone);
      return tz.TZDateTime(
        location,
        normalized.year,
        normalized.month,
        normalized.day,
      ).toUtc();
    } catch (_) {
      return DateTime.utc(normalized.year, normalized.month, normalized.day);
    }
  }

  /// Local calendar day for a schedule instant stored as UTC.
  static DateTime? calendarDayFromScheduleInstant(
    dynamic value,
    String timezone,
  ) {
    final parsed = _dateTimeFromValue(value);
    if (parsed == null) return null;
    try {
      final location = tz.getLocation(timezone);
      final local = tz.TZDateTime.from(parsed.toUtc(), location);
      return DateTime(local.year, local.month, local.day);
    } catch (_) {
      return _dateOnly(parsed.toUtc());
    }
  }

  static DateTime _dtstartAtScheduleMidnight(DateTime day, String timezone) =>
      dtstartAtScheduleMidnight(day, timezone);
}

/// Human-readable label for a schedule API row.
String scheduleSummaryLabel(Map<String, dynamic> schedule) {
  return scheduleSummaryFromApi(schedule);
}

List<AnvilFieldOption<String>> taskRepeatTypeOptions({bool includeQuota = false}) {
  return TaskRepeatType.all
      .where((t) => t != TaskRepeatType.none)
      .where((t) => includeQuota || !TaskRepeatType.isQuotaRepeatType(t))
      .map(
        (t) => AnvilFieldOption(
          value: t,
          label: TaskRepeatType.labelFor(t),
        ),
      )
      .toList();
}

List<AnvilFieldOption<int>> taskWeekdayOptions() => const [
      AnvilFieldOption(value: 1, label: 'Mon'),
      AnvilFieldOption(value: 2, label: 'Tue'),
      AnvilFieldOption(value: 3, label: 'Wed'),
      AnvilFieldOption(value: 4, label: 'Thu'),
      AnvilFieldOption(value: 5, label: 'Fri'),
      AnvilFieldOption(value: 6, label: 'Sat'),
      AnvilFieldOption(value: 7, label: 'Sun'),
    ];

List<AnvilFieldOption<int>> taskMonthDayOptions() => List.generate(
      31,
      (i) => AnvilFieldOption(value: i + 1, label: '${i + 1}'),
    );
