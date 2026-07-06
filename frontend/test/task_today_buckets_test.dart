import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
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
}
