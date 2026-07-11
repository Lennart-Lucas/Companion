import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/core/scheduling/schedule_form_values.dart';

void main() {
  test('tracker submit uses edited anchor when schedule_start_date is stale', () {
    final values = <String, dynamic>{
      'name': 'Morning routine',
      'check_in_type': TrackerCheckInType.task,
      'habit_direction': TrackerHabitDirection.build,
      TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
      TaskScheduleFormKeys.repeatEnabled: true,
      TaskScheduleFormKeys.repeatType: TaskRepeatType.weekdays,
      TaskScheduleFormKeys.weekdays: [1, 2, 3, 4, 5],
      TaskScheduleFormKeys.timezone: 'Europe/Brussels',
      TaskScheduleFormKeys.anchor: DateTime(2026, 6, 29),
      TaskScheduleFormKeys.startDate: DateTime(2026, 6, 25),
    };

    final tracker = Tracker.fromFormValues(values, id: '42');
    final json = tracker.toJson();

    expect(tracker.startDate, DateTime(2026, 6, 29));
    expect(json['start_date'], isNotNull);
    final schedule = json['schedule'] as Map<String, dynamic>;
    expect(schedule['dtstart'], isNot(contains('2026-06-24')));
    expect(schedule['dtstart'], isNot(contains('2026-06-25T')));
    expect(schedule['start_date'], schedule['dtstart']);
  });

  test('hydrate merge prefers tracker anchor over stale schedule anchor', () {
    final merged = TaskScheduleFormValues.mergeAnchorOnlyScheduleFormValues(
      entityValues: {
        'name': 'Test',
        TaskScheduleFormKeys.anchor: DateTime(2026, 6, 29),
      },
      scheduleFormValues: {
        TaskScheduleFormKeys.anchor: DateTime(2026, 6, 25),
        TaskScheduleFormKeys.startDate: DateTime(2026, 6, 25),
        TaskScheduleFormKeys.repeatType: TaskRepeatType.weekdays,
      },
      existingScheduleId: '7',
    );

    expect(merged[TaskScheduleFormKeys.startDate], isNull);
    expect(merged[TaskScheduleFormKeys.anchor], DateTime(2026, 6, 29));
  });
}
