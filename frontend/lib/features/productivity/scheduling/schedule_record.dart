import 'package:anvil_foundry/anvil_foundry.dart';

import 'package:frontend/core/records/record_json_utils.dart';

/// Cached schedule entity for [GetRecordRequested] hydration on edit.
class ScheduleRecord extends Record {
  @override
  final RecordId id;
  @override
  RecordType get recordType => 'schedules';

  final DateTime dtstart;
  final String? rrule;
  final String timezone;
  final List<DateTime> rdates;
  final List<DateTime> exdates;

  ScheduleRecord({
    required this.id,
    required this.dtstart,
    required this.timezone,
    this.rrule,
    this.rdates = const [],
    this.exdates = const [],
  });

  factory ScheduleRecord.fromJson(Map<String, dynamic> json) {
    final data = RecordJsonUtils.unwrapJson(json);
    return ScheduleRecord(
      id: RecordJsonUtils.idFromJson(data),
      dtstart: RecordJsonUtils.dateTimeFromJson(data['dtstart'] ?? data['anchor_at']) ??
          DateTime.now().toUtc(),
      rrule: data['rrule']?.toString(),
      timezone: data['timezone']?.toString() ?? 'UTC',
      rdates: _datesFromResponse(data['rdates'] ?? data['specific_dates']),
      exdates: _datesFromResponse(data['exdates'] ?? data['exclusions']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'dtstart': dtstart.toUtc().toIso8601String(),
        if (rrule != null) 'rrule': rrule,
        'timezone': timezone,
        'rdates': rdates
            .map(
              (d) => {
                'occurrence_date':
                    DateTime(d.year, d.month, d.day).toIso8601String().split('T').first,
              },
            )
            .toList(),
        'exdates': exdates
            .map(
              (d) => {
                'excluded_date':
                    DateTime(d.year, d.month, d.day).toIso8601String().split('T').first,
              },
            )
            .toList(),
      };

  static List<DateTime> _datesFromResponse(dynamic value) {
    if (value is! List) return [];
    final dates = <DateTime>[];
    for (final row in value) {
      if (row is Map) {
        final raw = row['occurrence_date'] ??
            row['excluded_date'] ??
            row['date'];
        final dt = RecordJsonUtils.dateTimeFromJson(raw);
        if (dt != null) {
          dates.add(RecordJsonUtils.dateOnly(dt));
        }
      } else {
        final dt = RecordJsonUtils.dateTimeFromJson(row);
        if (dt != null) dates.add(RecordJsonUtils.dateOnly(dt));
      }
    }
    return dates;
  }
}
