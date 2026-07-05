enum OverrideScope { fromDate, singleOccurrence }

class ScheduleOverrideData {
  const ScheduleOverrideData({
    required this.scope,
    required this.effectiveAt,
    required this.replacement,
  });

  final OverrideScope scope;
  final DateTime effectiveAt;
  final ScheduleBundle replacement;
}

class ScheduleBundle {
  const ScheduleBundle({
    required this.dtstart,
    required this.timezone,
    this.rrule,
    this.rdates = const [],
    this.exclusions = const {},
    this.overrides = const [],
    this.scheduleId,
  });

  final DateTime dtstart;
  final String timezone;
  final String? rrule;
  final List<DateTime> rdates;
  final Set<DateTime> exclusions;
  final List<ScheduleOverrideData> overrides;
  final String? scheduleId;
}
