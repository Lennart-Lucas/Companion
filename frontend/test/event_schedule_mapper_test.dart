import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/events/models/event.dart';

import 'package:frontend/core/scheduling/schedule_form_values.dart';

void main() {
  group('Event schedule payloads', () {
    test('off mode sends no schedule fields', () {
      final start = DateTime(2026, 8, 1, 10, 0);
      final event = Event.fromFormValues({
        'name': 'Meetup',
        'start_at': start,
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.off,
      });

      final json = event.toJson();
      expect(json['start_at'], start.toUtc().toIso8601String());
      expect(json.containsKey('schedule'), isFalse);
      expect(json.containsKey('schedule_id'), isFalse);
      expect(event.isRecurring, isFalse);
    });

    test('repeating mode sends inline schedule anchored to start_at', () {
      final start = DateTime.utc(2026, 8, 1, 10, 0);
      final event = Event.fromFormValues({
        'name': 'Weekly standup',
        'start_at': start,
        'end_at': DateTime.utc(2026, 8, 1, 11, 0),
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
        TaskScheduleFormKeys.repeatType: TaskRepeatType.everyNWeeks,
        TaskScheduleFormKeys.startDate: DateTime.utc(2026, 8, 1),
        TaskScheduleFormKeys.timezone: 'UTC',
        TaskScheduleFormKeys.interval: 1,
      });

      final json = event.toJson();
      expect(json['schedule'], isNotNull);
      expect(json['schedule']['rrule'], 'FREQ=WEEKLY;INTERVAL=1');
      expect(json['schedule']['dtstart'], start.toUtc().toIso8601String());
      expect(json['end_at'], isNotNull);
      expect(event.isRecurring, isTrue);
    });

    test('link mode sends schedule_id on create', () {
      final start = DateTime(2026, 8, 1, 10, 0);
      final event = Event.fromFormValues({
        'name': 'Linked event',
        'start_at': start,
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.link,
        TaskScheduleFormKeys.existingScheduleId: '7',
      });

      final json = event.toJson();
      expect(json['schedule_id'], 7);
      expect(json.containsKey('schedule'), isFalse);
    });

    test('off mode on update clears schedule', () {
      final event = Event.fromFormValues(
        {
          'name': 'Was repeating',
          TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.off,
          TaskScheduleFormKeys.originalScheduleId: '3',
          'start_at': DateTime(2026, 8, 1, 9, 0),
        },
        id: '12',
      );

      final json = event.toJson();
      expect(json['schedule_id'], isNull);
    });

    test('fromJson reads schedule_id and is_recurring', () {
      final event = Event.fromJson({
        'id': '5',
        'name': 'Series',
        'start_at': '2026-08-01T10:00:00Z',
        'schedule_id': 2,
        'is_recurring': true,
      });

      expect(event.scheduleId, '2');
      expect(event.isRecurring, isTrue);
    });
  });
}
