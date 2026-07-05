import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/scheduling/rrule_codec.dart';

void main() {
  test('patternToRrule round-trips daily', () {
    final rrule = patternToRrule(pattern: ScheduleRepeatType.everyNDays, interval: 2);
    expect(rrule, 'FREQ=DAILY;INTERVAL=2');
    expect(rruleToPattern(rrule!).pattern, ScheduleRepeatType.everyNDays);
  });

  test('patternToRrule encodes weekdays', () {
    final rrule = patternToRrule(
      pattern: ScheduleRepeatType.weekdays,
      interval: 1,
      weekdays: const [1, 3],
    );
    expect(rrule, 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE');
  });
}
