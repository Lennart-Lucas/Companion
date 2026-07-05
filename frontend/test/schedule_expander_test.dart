import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/scheduling/schedule_expander.dart';
import 'package:frontend/features/productivity/scheduling/schedule_types.dart';

void main() {
  test('expandOccurrences returns dtstart for non-recurring schedule', () {
    final dtstart = DateTime.utc(2026, 6, 7, 9);
    final bundle = ScheduleBundle(
      dtstart: dtstart,
      timezone: 'UTC',
    );

    final results = expandOccurrences(
      bundle,
      start: DateTime.utc(2026, 6, 1),
      end: DateTime.utc(2026, 6, 30),
    );

    expect(results, [dtstart]);
  });

  test('expandOccurrences expands daily RRULE', () {
    final bundle = ScheduleBundle(
      dtstart: DateTime.utc(2026, 6, 1, 9),
      timezone: 'UTC',
      rrule: 'FREQ=DAILY;INTERVAL=2',
    );

    final results = expandOccurrences(
      bundle,
      start: DateTime.utc(2026, 6, 1),
      end: DateTime.utc(2026, 6, 10),
      maxCount: 10,
    );

    expect(results.length, greaterThan(1));
    expect(results.first, DateTime.utc(2026, 6, 1, 9));
  });
}
