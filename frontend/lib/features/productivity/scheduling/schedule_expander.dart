import 'package:frontend/features/productivity/scheduling/schedule_types.dart';
import 'package:rrule/rrule.dart';
import 'package:timezone/timezone.dart' as tz;

DateTime _ensureUtc(DateTime dt) => dt.toUtc();

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

tz.Location _location(String timezone) {
  try {
    return tz.getLocation(timezone);
  } catch (_) {
    return tz.UTC;
  }
}

DateTime _dtstartLocal(ScheduleBundle bundle) {
  final loc = _location(bundle.timezone);
  return tz.TZDateTime.from(bundle.dtstart.toUtc(), loc);
}

DateTime _occurrenceAtLocalDate(ScheduleBundle bundle, DateTime day) {
  final loc = _location(bundle.timezone);
  final anchor = _dtstartLocal(bundle);
  final local = tz.TZDateTime(
    loc,
    day.year,
    day.month,
    day.day,
    anchor.hour,
    anchor.minute,
    anchor.second,
    anchor.millisecond,
    anchor.microsecond,
  );
  return local.toUtc();
}

DateTime _localDate(ScheduleBundle bundle, DateTime dt) {
  final loc = _location(bundle.timezone);
  final local = tz.TZDateTime.from(dt.toUtc(), loc);
  return DateTime(local.year, local.month, local.day);
}

bool _isExcluded(ScheduleBundle bundle, DateTime dt) {
  return bundle.exclusions.contains(_localDate(bundle, dt));
}

bool _inWindow(DateTime dt, DateTime start, DateTime end) {
  final t = _ensureUtc(dt);
  return !t.isBefore(_ensureUtc(start)) && !t.isAfter(_ensureUtc(end));
}

List<DateTime> _expandScheduleOnly(
  ScheduleBundle bundle, {
  required DateTime start,
  required DateTime end,
  required int maxCount,
}) {
  final results = <DateTime>[];

    if (bundle.rrule != null && bundle.rrule!.isNotEmpty) {
    final rule = RecurrenceRule.fromString('RRULE:${bundle.rrule}');
    final ruleStart = _dtstartLocal(bundle).toUtc();
    var after = start.toUtc();
    if (after.isBefore(ruleStart)) {
      after = ruleStart;
    }
    final instances = rule.getAllInstances(
      start: ruleStart,
      after: after,
      includeAfter: true,
      before: end.toUtc(),
      includeBefore: true,
    );
    results.addAll(instances.map(_ensureUtc));
  }

  for (final d in bundle.rdates) {
    final occ = _occurrenceAtLocalDate(bundle, _dateOnly(d));
    if (_inWindow(occ, start, end)) {
      results.add(occ);
    }
  }

  if (bundle.rrule == null && bundle.rdates.isEmpty) {
    final anchor = _ensureUtc(bundle.dtstart);
    if (_inWindow(anchor, start, end)) {
      results.add(anchor);
    }
  }

  results.sort();
  final unique = <DateTime>{};
  final deduped = <DateTime>[];
  for (final r in results) {
    if (unique.add(r)) deduped.add(r);
  }
  return deduped.take(maxCount).toList();
}

List<DateTime> _applyExclusions(
  ScheduleBundle bundle,
  List<DateTime> occurrences,
  int maxCount,
) {
  return occurrences.where((o) => !_isExcluded(bundle, o)).take(maxCount).toList();
}

List<DateTime> _expandWithOverrides(
  ScheduleBundle bundle, {
  required DateTime start,
  required DateTime end,
  required int maxCount,
}) {
  start = _ensureUtc(start);
  end = _ensureUtc(end);

  final fromDateOverrides = bundle.overrides
      .where((o) => o.scope == OverrideScope.fromDate)
      .toList()
    ..sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));

  if (fromDateOverrides.isEmpty && bundle.overrides.isEmpty) {
    return _applyExclusions(
      bundle,
      _expandScheduleOnly(bundle, start: start, end: end, maxCount: maxCount),
      maxCount,
    );
  }

  final segments = <({DateTime segStart, DateTime segEnd, ScheduleBundle active, bool exclusiveEnd})>[];
  var cursor = start;
  var active = bundle;

  for (final override in fromDateOverrides) {
    final boundary = _ensureUtc(override.effectiveAt);
    if (boundary.isAfter(end)) break;
    if (cursor.isBefore(boundary)) {
      final segEnd = boundary.isBefore(end) ? boundary : end;
      if (cursor.isBefore(segEnd)) {
        segments.add((
          segStart: cursor,
          segEnd: segEnd,
          active: active,
          exclusiveEnd: true,
        ));
      }
    }
    active = override.replacement;
    cursor = boundary;
  }

  if (!cursor.isAfter(end)) {
    segments.add((
      segStart: cursor,
      segEnd: end,
      active: active,
      exclusiveEnd: false,
    ));
  }

  if (segments.isEmpty) {
    segments.add((
      segStart: start,
      segEnd: end,
      active: bundle,
      exclusiveEnd: false,
    ));
  }

  final results = <DateTime>[];
  for (final segment in segments) {
    if (segment.segStart.isAfter(segment.segEnd)) continue;
    final chunk = _expandScheduleOnly(
      segment.active,
      start: segment.segStart,
      end: segment.segEnd,
      maxCount: maxCount - results.length,
    );
    final boundary = _ensureUtc(segment.segEnd);
    for (final occ in chunk) {
      if (segment.exclusiveEnd && !_ensureUtc(occ).isBefore(boundary)) {
        continue;
      }
      results.add(occ);
    }
    if (results.length >= maxCount) break;
  }

  final merged = results.map(_ensureUtc).toSet().toList()..sort();

  for (final override in bundle.overrides.where(
    (o) => o.scope == OverrideScope.singleOccurrence,
  )) {
    final eff = _ensureUtc(override.effectiveAt);
    merged.removeWhere((r) => r == eff);
    final replacement = override.replacement;
    if ((replacement.rrule == null || replacement.rrule!.isEmpty) &&
        replacement.rdates.isEmpty) {
      final replAt = _ensureUtc(replacement.dtstart);
      if (_inWindow(replAt, start, end)) merged.add(replAt);
    } else {
      final repl = _expandScheduleOnly(
        replacement,
        start: eff.subtract(const Duration(seconds: 1)),
        end: eff.add(const Duration(seconds: 1)),
        maxCount: 1,
      );
      if (repl.isNotEmpty) {
        merged.add(repl.first);
      } else if (_inWindow(eff, start, end)) {
        merged.add(eff);
      }
    }
  }

  merged.sort();
  return _applyExclusions(bundle, merged, maxCount);
}

List<DateTime> expandOccurrences(
  ScheduleBundle bundle, {
  required DateTime start,
  required DateTime end,
  int maxCount = 500,
}) {
  if (maxCount < 1) return [];
  start = _ensureUtc(start);
  end = _ensureUtc(end);
  if (start.isAfter(end)) return [];

  if (bundle.overrides.isNotEmpty) {
    return _expandWithOverrides(
      bundle,
      start: start,
      end: end,
      maxCount: maxCount,
    );
  }

  return _applyExclusions(
    bundle,
    _expandScheduleOnly(bundle, start: start, end: end, maxCount: maxCount),
    maxCount,
  );
}
