import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_filter.dart';

void main() {
  final now = DateTime(2026, 6, 10);

  TaskListEntry entryWithStatus(
    String status, {
    DateTime? plannedAt,
  }) {
    final task = Task(
      id: '1',
      name: 'Task',
      status: status,
      plannedAt: plannedAt,
    );
    return TaskListEntry(
      task: task,
      status: status,
      priority: 'medium',
      subtasks: const [],
      isVirtual: true,
      occurrenceAt: plannedAt,
      displayAt: plannedAt,
    );
  }

  group('filterVisibleTaskListEntries', () {
    test('hides completed entries on today and future by default', () {
      final entries = [
        entryWithStatus('pending', plannedAt: DateTime(2026, 6, 10)),
        entryWithStatus('completed', plannedAt: DateTime(2026, 6, 10)),
        entryWithStatus('in_progress', plannedAt: DateTime(2026, 6, 11)),
      ];

      final filtered = filterVisibleTaskListEntries(entries, now: now);

      expect(filtered.map((e) => e.status), ['pending', 'in_progress']);
    });

    test('keeps completed entries on past dates', () {
      final entries = [
        entryWithStatus('completed', plannedAt: DateTime(2026, 6, 9)),
        entryWithStatus('completed', plannedAt: DateTime(2026, 6, 10)),
      ];

      final filtered = filterVisibleTaskListEntries(entries, now: now);

      expect(filtered.length, 1);
      expect(filtered.single.status, 'completed');
      expect(filtered.single.displayAt?.day, 9);
    });

    test('keeps completed entries when hideCompleted is false', () {
      final entries = [
        entryWithStatus('pending', plannedAt: DateTime(2026, 6, 10)),
        entryWithStatus('completed', plannedAt: DateTime(2026, 6, 10)),
      ];

      final filtered = filterVisibleTaskListEntries(
        entries,
        hideCompleted: false,
        now: now,
      );

      expect(filtered.length, 2);
    });
  });

  group('filterVisibleTimelineItems', () {
    test('hides completed tasks and succeeded tracker check-ins for today', () {
      final tracker = Tracker(
        id: 't1',
        name: 'Habit',
        checkInType: TrackerCheckInType.task,
        startDate: DateTime(2026, 1, 1),
      );
      final succeededCheckIn = TrackerCheckIn(
        id: 1,
        checkInAt: DateTime(2026, 6, 10, 8),
        checkInType: TrackerCheckInType.task,
        logged: true,
        skipped: false,
        completed: true,
      );
      final pendingCheckIn = TrackerCheckIn(
        id: 2,
        checkInAt: DateTime(2026, 6, 10, 18),
        checkInType: TrackerCheckInType.task,
        logged: false,
        skipped: false,
        completed: false,
      );

      final items = <TimelineSortableItem>[
        TaskTimelineItem(
          entryWithStatus('completed', plannedAt: DateTime(2026, 6, 10)),
        ),
        TaskTimelineItem(
          entryWithStatus('pending', plannedAt: DateTime(2026, 6, 10)),
        ),
        TrackerTimelineItem(tracker: tracker, checkIn: succeededCheckIn),
        TrackerTimelineItem(tracker: tracker, checkIn: pendingCheckIn),
      ];

      final filtered = filterVisibleTimelineItems(
        items,
        listToday: DateTime(2026, 6, 10),
      );

      expect(filtered.length, 2);
      expect(filtered[0], isA<TaskTimelineItem>());
      expect((filtered[0] as TaskTimelineItem).entry.status, 'pending');
      expect(filtered[1], isA<TrackerTimelineItem>());
      expect((filtered[1] as TrackerTimelineItem).checkIn.id, 2);
    });

    test('keeps completed items on past dates', () {
      final tracker = Tracker(
        id: 't1',
        name: 'Habit',
        checkInType: TrackerCheckInType.task,
        startDate: DateTime(2026, 1, 1),
      );
      final succeededCheckIn = TrackerCheckIn(
        id: 1,
        checkInAt: DateTime(2026, 6, 9, 8),
        checkInType: TrackerCheckInType.task,
        logged: true,
        skipped: false,
        completed: true,
      );

      final items = <TimelineSortableItem>[
        TaskTimelineItem(
          entryWithStatus('completed', plannedAt: DateTime(2026, 6, 9)),
        ),
        TrackerTimelineItem(tracker: tracker, checkIn: succeededCheckIn),
      ];

      final filtered = filterVisibleTimelineItems(items, listToday: now);

      expect(filtered.length, 2);
    });

    test('hides logged goal check-ins for today', () {
      final goal = Goal(
        id: 'g1',
        name: 'Books',
        goalType: GoalType.count,
        target: 12,
        unit: 'books',
        direction: GoalDirection.increasing,
        startDate: DateTime(2026, 1, 1),
      );
      final logged = GoalCheckIn(
        id: 1,
        checkInAt: DateTime(2026, 6, 10, 8),
        goalType: GoalType.count,
        logged: true,
        countValue: 2,
      );
      final pending = GoalCheckIn(
        id: 2,
        checkInAt: DateTime(2026, 6, 10, 18),
        goalType: GoalType.count,
        logged: false,
      );

      final items = <TimelineSortableItem>[
        GoalTimelineItem(goal: goal, checkIn: logged),
        GoalTimelineItem(goal: goal, checkIn: pending),
      ];

      final filtered = filterVisibleTimelineItems(
        items,
        listToday: DateTime(2026, 6, 10),
      );

      expect(filtered.length, 1);
      expect(filtered.single, isA<GoalTimelineItem>());
      expect((filtered.single as GoalTimelineItem).checkIn.id, 2);
    });

    test('keeps quit over-limit tracker check-ins visible for today', () {
      final quitTracker = Tracker(
        id: 'quit',
        name: 'Sugar',
        startDate: DateTime(2026, 1, 1),
        checkInType: TrackerCheckInType.count,
        target: 3,
        unit: 'snacks',
        habitDirection: TrackerHabitDirection.quit,
      );
      final overLimit = TrackerCheckIn(
        id: 1,
        checkInAt: DateTime(2026, 6, 10, 8),
        checkInType: TrackerCheckInType.count,
        logged: true,
        skipped: false,
        countValue: 5,
      );

      final items = <TimelineSortableItem>[
        TrackerTimelineItem(tracker: quitTracker, checkIn: overLimit),
      ];

      final filtered = filterVisibleTimelineItems(
        items,
        listToday: DateTime(2026, 6, 10),
      );

      expect(filtered.length, 1);
      expect(filtered.single, isA<TrackerTimelineItem>());
    });
  });
}
