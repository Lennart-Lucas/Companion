import 'package:anvil_foundry/anvil_foundry.dart';

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
    final data = _unwrap(json);
    return ScheduleRecord(
      id: data['id']?.toString() ?? '',
      dtstart: _dateTimeFromJson(data['dtstart'] ?? data['anchor_at']) ??
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

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static List<DateTime> _datesFromResponse(dynamic value) {
    if (value is! List) return [];
    final dates = <DateTime>[];
    for (final row in value) {
      if (row is Map) {
        final raw = row['occurrence_date'] ??
            row['excluded_date'] ??
            row['date'];
        final dt = _dateTimeFromJson(raw);
        if (dt != null) {
          dates.add(DateTime(dt.year, dt.month, dt.day));
        }
      } else {
        final dt = _dateTimeFromJson(row);
        if (dt != null) dates.add(DateTime(dt.year, dt.month, dt.day));
      }
    }
    return dates;
  }
}
