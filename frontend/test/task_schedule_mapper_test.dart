import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/core/scheduling/schedule_form_values.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  tz_data.initializeTimeZones();

  group('TaskScheduleFormValues', () {
    test('defaultCreateValues sets start date and anchor to today', () {
      final today = TaskScheduleFormValues.defaultStartDate();
      final values = TaskScheduleFormValues.defaultCreateValues();

      expect(values[TaskScheduleFormKeys.startDate], today);
      expect(values[TaskScheduleFormKeys.anchor], today);
      expect(values[TaskScheduleFormKeys.scheduleMode], TaskScheduleMode.off);
    });

    test('toScheduleCreateJson returns null when mode is off', () {
      final schedule = TaskScheduleFormValues.fromFormMap({
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.off,
      });
      expect(schedule.toScheduleCreateJson(), isNull);
    });

    test('oneOffScheduleFromDeadline builds dtstart-only schedule', () {
      final deadline = DateTime(2026, 5, 21, 14, 30);
      final schedule = TaskScheduleFormValues.fromFormMap({
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.oneOff,
        TaskScheduleFormKeys.timezone: 'Europe/Brussels',
      });

      final json = schedule.oneOffScheduleFromDeadline(deadline)!;
      expect(json['timezone'], 'Europe/Brussels');
      expect(json['dtstart'], deadline.toUtc().toIso8601String());
      expect(json.containsKey('rrule'), isFalse);
    });

    test('toScheduleCreateJson emits RRULE for daily pattern', () {
      final start = DateTime(2026, 5, 21);
      final schedule = TaskScheduleFormValues(
        mode: TaskScheduleMode.repeating,
        repeatType: TaskRepeatType.everyNDays,
        startDate: start,
        timezone: 'UTC',
        interval: 1,
      );

      final json = schedule.toScheduleCreateJson()!;
      expect(json['rrule'], 'FREQ=DAILY;INTERVAL=1');
      expect(json['timezone'], 'UTC');
      expect(json['dtstart'], DateTime.utc(2026, 5, 21).toIso8601String());
      expect(json['start_date'], DateTime.utc(2026, 5, 21).toIso8601String());
    });

    test('toScheduleCreateJson falls back to deadline for dtstart', () {
      final deadline = DateTime(2026, 6, 15);
      final schedule = TaskScheduleFormValues(
        mode: TaskScheduleMode.repeating,
        repeatType: TaskRepeatType.everyNDays,
        timezone: 'UTC',
        interval: 1,
      );

      final json = schedule.toScheduleCreateJson(fallbackAnchor: deadline)!;
      expect(json['dtstart'], DateTime.utc(2026, 6, 15).toIso8601String());
      expect(json.containsKey('start_date'), isFalse);
    });

    test('legacy anchor field still works for goal/tracker forms', () {
      final anchor = DateTime(2026, 1, 1);
      final schedule = TaskScheduleFormValues(
        mode: TaskScheduleMode.repeating,
        repeatType: TaskRepeatType.weekdays,
        anchor: anchor,
        timezone: 'Europe/Amsterdam',
        interval: 1,
        weekdays: const [1, 3, 5],
      );

      final json = schedule.toScheduleCreateJson()!;
      expect(json['rrule'], 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE,FR');
      expect(
        json['dtstart'],
        DateTime.utc(2025, 12, 31, 23).toIso8601String(),
      );
    });

    test('toScheduleCreateJson includes rdates for specific dates', () {
      final schedule = TaskScheduleFormValues(
        mode: TaskScheduleMode.repeating,
        repeatType: TaskRepeatType.specificDates,
        startDate: DateTime(2026, 1, 1),
        timezone: 'UTC',
        specificDates: [DateTime(2026, 6, 1), DateTime(2026, 6, 15)],
      );

      final json = schedule.toScheduleCreateJson()!;
      expect(json['rdates'], ['2026-06-01', '2026-06-15']);
      expect(json.containsKey('rrule'), isFalse);
    });

    test('validate accepts fallback anchor when start date unset', () {
      final error = TaskScheduleFormValues.validate(
        {
          TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
          TaskScheduleFormKeys.repeatType: TaskRepeatType.everyNDays,
          TaskScheduleFormKeys.timezone: 'UTC',
          TaskScheduleFormKeys.interval: 1,
        },
        fallbackAnchor: DateTime(2026, 5, 21),
      );
      expect(error, isNull);
    });

    test('validate requires weekdays when type is weekdays', () {
      final error = TaskScheduleFormValues.validate({
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
        TaskScheduleFormKeys.repeatType: TaskRepeatType.weekdays,
        TaskScheduleFormKeys.startDate: DateTime(2026, 1, 1),
        TaskScheduleFormKeys.timezone: 'UTC',
        TaskScheduleFormKeys.interval: 1,
        TaskScheduleFormKeys.weekdays: <int>[],
      });
      expect(error, isNotNull);
    });

    test('validate requires deadline for one-off mode', () {
      final error = TaskScheduleFormValues.validate({
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.oneOff,
        TaskScheduleFormKeys.timezone: 'UTC',
      });
      expect(error, isNotNull);
    });

    test('validate requires linked schedule for link mode', () {
      final error = TaskScheduleFormValues.validate({
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.link,
      });
      expect(error, isNotNull);
    });

    test('fromScheduleResponse maps non-recurring to one-off mode', () {
      final schedule = TaskScheduleFormValues.fromScheduleResponse({
        'dtstart': '2026-05-21T09:00:00Z',
        'timezone': 'UTC',
      });

      expect(schedule.mode, TaskScheduleMode.oneOff);
    });

    test('fromScheduleResponse decodes RRULE pattern', () {
      final schedule = TaskScheduleFormValues.fromScheduleResponse({
        'dtstart': '2026-05-21T09:00:00Z',
        'start_date': '2026-06-01T00:00:00Z',
        'timezone': 'UTC',
        'rrule': 'FREQ=DAILY;INTERVAL=1',
      });

      expect(schedule.startDate, DateTime(2026, 6, 1));
      expect(schedule.mode, TaskScheduleMode.repeating);
      expect(schedule.repeatType, TaskRepeatType.everyNDays);
    });
  });

  group('Task.toJson schedule', () {
    test('includes inline schedule on create when repeating', () {
      final task = Task.fromFormValues({
        'name': 'Daily standup',
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
        TaskScheduleFormKeys.repeatType: TaskRepeatType.everyNDays,
        TaskScheduleFormKeys.startDate: DateTime(2026, 5, 21),
        TaskScheduleFormKeys.timezone: 'UTC',
        TaskScheduleFormKeys.interval: 1,
      });

      final json = task.toJson();
      expect(json['schedule'], isNotNull);
      expect(json['schedule']['dtstart'], isNotNull);
      expect(json['schedule']['rrule'], 'FREQ=DAILY;INTERVAL=1');
      expect(json['schedule_id'], isNull);
      expect(json.containsKey('schedule_id'), isFalse);
    });

    test('one-off sends inline dtstart schedule from deadline', () {
      final deadline = DateTime(2026, 7, 1, 9, 0);
      final task = Task.fromFormValues({
        'name': 'One shot',
        'deadline': deadline,
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.oneOff,
        TaskScheduleFormKeys.timezone: 'UTC',
      });

      final json = task.toJson();
      expect(json['schedule']['dtstart'], deadline.toUtc().toIso8601String());
      expect(json['deadline'], deadline.toUtc().toIso8601String());
    });

    test('link mode sends schedule_id on create', () {
      final task = Task.fromFormValues({
        'name': 'Linked task',
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.link,
        TaskScheduleFormKeys.existingScheduleId: '42',
      });

      final json = task.toJson();
      expect(json['schedule_id'], 42);
      expect(json.containsKey('schedule'), isFalse);
    });

    test('uses deadline as dtstart when start date omitted', () {
      final deadline = DateTime(2026, 7, 1);
      final task = Task.fromFormValues({
        'name': 'Daily standup',
        'deadline': deadline,
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
        TaskScheduleFormKeys.repeatType: TaskRepeatType.everyNDays,
        TaskScheduleFormKeys.timezone: 'UTC',
        TaskScheduleFormKeys.interval: 1,
      });

      final json = task.toJson();
      expect(
        json['schedule']['dtstart'],
        DateTime.utc(2026, 7, 1).toIso8601String(),
      );
    });

    test('clears schedule on update when mode is off', () {
      final task = Task.fromFormValues(
        {
          'name': 'Was repeating',
          TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.off,
          TaskScheduleFormKeys.originalScheduleId: '42',
        },
        id: '10',
      );

      final json = task.toJson();
      expect(json['schedule_id'], isNull);
      expect(json.containsKey('schedule'), isFalse);
    });

    test('forces pending status when schedule owns dates', () {
      final task = Task.fromFormValues({
        'name': 'Daily standup',
        'status': 'completed',
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
        TaskScheduleFormKeys.repeatType: TaskRepeatType.everyNDays,
        TaskScheduleFormKeys.startDate: DateTime(2026, 5, 21),
        TaskScheduleFormKeys.timezone: 'UTC',
        TaskScheduleFormKeys.interval: 1,
      });

      expect(task.status, 'pending');
      expect(task.toJson()['status'], 'pending');
    });
  });
}
