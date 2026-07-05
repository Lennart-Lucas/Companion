import 'package:frontend/features/productivity/scheduling/schedule_types.dart';

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

List<DateTime> _datesFromResponseList(dynamic raw) {
  if (raw is! List) return [];
  final dates = <DateTime>[];
  for (final row in raw) {
    if (row is Map) {
      final rawDate = row['occurrence_date'] ??
          row['excluded_date'] ??
          row['date'];
      final dt = _parseDate(rawDate);
      if (dt != null) dates.add(_dateOnly(dt));
    } else {
      final dt = _parseDate(row);
      if (dt != null) dates.add(_dateOnly(dt));
    }
  }
  return dates;
}

ScheduleBundle scheduleBundleFromJson(Map<String, dynamic> json) {
  return ScheduleBundle(
    dtstart: _parseDate(json['dtstart'] ?? json['anchor_at'])?.toUtc() ??
        DateTime.now().toUtc(),
    timezone: json['timezone']?.toString() ?? 'UTC',
    rrule: json['rrule']?.toString(),
    rdates: _datesFromResponseList(json['rdates'] ?? json['specific_dates']),
    exclusions: _datesFromResponseList(json['exdates'] ?? json['exclusions'])
        .toSet(),
    scheduleId: json['id']?.toString(),
  );
}
