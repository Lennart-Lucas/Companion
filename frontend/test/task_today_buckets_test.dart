import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/task_today_buckets.dart';

void main() {
  final today = DateTime(2026, 7, 6);

  TaskListEntry entry({
    String id = '1',
    String status = 'pending',
    DateTime? plannedAt,
    DateTime? deadline,
    DateTime? resolvedAt,
    DateTime? updatedAt,
  }) {
    final task = Task(
      id: id,
      name: 'Task $id',
      status: status,
      plannedAt: plannedAt,
      deadline: deadline,
      updatedAt: updatedAt,
    );
    return TaskListEntry(
      task: task,
      status: status,
      priority: 'medium',
      subtasks: const [],
      isVirtual: true,
      resolvedAt: resolvedAt,
    );
  }

  group('computeTaskTodayBucketCounts', () {
    test('nested todo includes overdue', () {
      final entries = [
        entry(id: '1', deadline: DateTime(2026, 7, 5)),
        entry(id: '2', deadline: DateTime(2026, 7, 6)),
        entry(id: '3', deadline: DateTime(2026, 7, 7)),
      ];

      final counts = computeTaskTodayBucketCounts(entries, today);

      expect(counts.overdue, 1);
      expect(counts.todo, 2);
    });

    test('counts unplanned and completed today', () {
      final entries = [
        entry(id: 'u'),
        entry(
          id: 'c',
          status: 'completed',
          resolvedAt: DateTime(2026, 7, 6, 14),
        ),
      ];

      final counts = computeTaskTodayBucketCounts(entries, today);

      expect(counts.unplanned, 1);
      expect(counts.completed, 1);
    });
  });

  group('classifyTaskTodayBucket', () {
    test('priority order is completed, unplanned, overdue, todo', () {
      expect(
        classifyTaskTodayBucket(
          entry(
            status: 'completed',
            resolvedAt: DateTime(2026, 7, 6),
            deadline: DateTime(2026, 7, 1),
          ),
          today,
        ),
        TaskTodayBucket.completed,
      );
      expect(
        classifyTaskTodayBucket(entry(id: 'u'), today),
        TaskTodayBucket.unplanned,
      );
      expect(
        classifyTaskTodayBucket(
          entry(deadline: DateTime(2026, 7, 5)),
          today,
        ),
        TaskTodayBucket.overdue,
      );
      expect(
        classifyTaskTodayBucket(
          entry(deadline: DateTime(2026, 7, 6)),
          today,
        ),
        TaskTodayBucket.todo,
      );
    });
  });

  group('taskEntriesForTodayBucket', () {
    test('returns matching entries for unplanned bucket', () {
      final unplanned = entry(id: 'u');
      final overdue = entry(id: 'o', deadline: DateTime(2026, 7, 5));

      final filtered = taskEntriesForTodayBucket(
        [unplanned, overdue],
        TaskTodayBucket.unplanned,
        today,
      );

      expect(filtered.length, 1);
      expect(filtered.single.task.id, 'u');
    });
  });

  group('tracker today buckets', () {
    final tracker = Tracker(
      id: 't1',
      name: 'Habit',
      checkInType: TrackerCheckInType.task,
      startDate: DateTime(2026, 1, 1),
    );

    TrackerTimelineItem trackerItem(TrackerCheckIn checkIn) {
      return TrackerTimelineItem(tracker: tracker, checkIn: checkIn);
    }

    test('pending and succeeded today check-ins count in To Do and Completed', () {
      final items = [
        trackerItem(
          TrackerCheckIn(
            id: 1,
            checkInAt: DateTime(2026, 7, 6, 8),
            checkInType: TrackerCheckInType.task,
            logged: true,
            skipped: false,
            completed: true,
          ),
        ),
        trackerItem(
          TrackerCheckIn(
            id: 2,
            checkInAt: DateTime(2026, 7, 6, 18),
            checkInType: TrackerCheckInType.task,
            logged: false,
            skipped: false,
            completed: false,
          ),
        ),
      ];

      final counts = computeTaskTodayBucketCounts(
        const [],
        today,
        trackerItems: items,
        now: DateTime(2026, 7, 6, 12),
      );

      expect(counts.todo, 1);
      expect(counts.completed, 1);
      expect(counts.overdue, 0);
      expect(counts.unplanned, 0);
    });

    test('check-ins on other days do not affect today buckets', () {
      final items = [
        trackerItem(
          TrackerCheckIn(
            id: 1,
            checkInAt: DateTime(2026, 7, 5, 8),
            checkInType: TrackerCheckInType.task,
            logged: false,
            skipped: false,
            completed: false,
          ),
        ),
      ];

      final counts = computeTaskTodayBucketCounts(
        const [],
        today,
        trackerItems: items,
        now: DateTime(2026, 7, 6, 12),
      );

      expect(counts.todo, 0);
      expect(counts.completed, 0);
      expect(counts.overdue, 0);
      expect(counts.unplanned, 0);
    });

    test('trackerItemsForTodayBucket excludes overdue and unplanned', () {
      final pending = trackerItem(
        TrackerCheckIn(
          id: 1,
          checkInAt: DateTime(2026, 7, 6, 18),
          checkInType: TrackerCheckInType.task,
          logged: false,
          skipped: false,
          completed: false,
        ),
      );

      expect(
        trackerItemsForTodayBucket(
          [pending],
          TaskTodayBucket.todo,
          today,
          now: DateTime(2026, 7, 6, 12),
        ).length,
        1,
      );
      expect(
        trackerItemsForTodayBucket(
          [pending],
          TaskTodayBucket.overdue,
          today,
          now: DateTime(2026, 7, 6, 12),
        ),
        isEmpty,
      );
      expect(
        trackerItemsForTodayBucket(
          [pending],
          TaskTodayBucket.unplanned,
          today,
          now: DateTime(2026, 7, 6, 12),
        ),
        isEmpty,
      );
    });
  });
}
