import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/shared/services/productivity_date_range.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';

void main() {
  final weekStart = DateTime(2026, 7, 6);
  final weekEnd = DateTime(2026, 7, 12);

  group('calendarDayRangeOverlaps', () {
    test('returns true when ranges overlap', () {
      expect(
        calendarDayRangeOverlaps(
          weekStart,
          weekEnd,
          rangeStart: DateTime(2026, 7, 1),
          rangeEnd: DateTime(2026, 7, 10),
        ),
        isTrue,
      );
    });

    test('returns false when range ends before window', () {
      expect(
        calendarDayRangeOverlaps(
          weekStart,
          weekEnd,
          rangeStart: DateTime(2026, 1, 1),
          rangeEnd: DateTime(2026, 7, 5),
        ),
        isFalse,
      );
    });

    test('returns false when range starts after window', () {
      expect(
        calendarDayRangeOverlaps(
          weekStart,
          weekEnd,
          rangeStart: DateTime(2026, 7, 13),
        ),
        isFalse,
      );
    });

    test('treats null bounds as open-ended', () {
      expect(
        calendarDayRangeOverlaps(
          weekStart,
          weekEnd,
          rangeStart: DateTime(2026, 1, 1),
        ),
        isTrue,
      );
      expect(
        calendarDayRangeOverlaps(
          weekStart,
          weekEnd,
          rangeEnd: DateTime(2026, 12, 31),
        ),
        isTrue,
      );
    });
  });

  group('entity active helpers', () {
    test('goalActiveInRange respects goal end date', () {
      final ended = Goal(
        id: 'g1',
        name: 'Ended',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30),
        target: 1,
        unit: 'x',
      );
      final active = Goal(
        id: 'g2',
        name: 'Active',
        startDate: DateTime(2026, 1, 1),
        target: 1,
        unit: 'x',
      );

      expect(goalActiveInRange(ended, weekStart, weekEnd), isFalse);
      expect(goalActiveInRange(active, weekStart, weekEnd), isTrue);
    });

    test('trackerActiveInHorizon excludes future trackers', () {
      final horizon = TaskListHorizon.forLocalDays(weekStart, weekEnd);
      final future = Tracker(
        id: 't1',
        name: 'Future',
        startDate: DateTime(2026, 8, 1),
        checkInType: TrackerCheckInType.task,
        habitDirection: TrackerHabitDirection.build,
      );

      expect(trackerActiveInHorizon(future, horizon), isFalse);
    });

    test('projectActiveInRange uses start date and deadline', () {
      final active = Project(
        id: 'p1',
        name: 'Active',
        startDate: DateTime(2026, 7, 1),
        deadline: DateTime(2026, 7, 31),
      );
      final ended = Project(
        id: 'p2',
        name: 'Ended',
        startDate: DateTime(2026, 1, 1),
        deadline: DateTime(2026, 6, 30),
      );
      final unscheduled = Project(
        id: 'p3',
        name: 'No dates',
      );

      expect(projectActiveInRange(active, weekStart, weekEnd), isTrue);
      expect(projectActiveInRange(ended, weekStart, weekEnd), isFalse);
      expect(projectActiveInRange(unscheduled, weekStart, weekEnd), isTrue);
    });
  });
}
