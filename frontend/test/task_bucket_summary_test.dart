import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/services/task_bucket_summary.dart';
import 'package:frontend/features/productivity/services/task_list_builder.dart';

Task _task({
  required String id,
  required String name,
  DateTime? plannedAt,
  DateTime? deadline,
  DateTime? updatedAt,
  bool isRecurring = false,
  String status = 'pending',
}) =>
    Task(
      id: id,
      name: name,
      plannedAt: plannedAt,
      deadline: deadline,
      updatedAt: updatedAt,
      isRecurring: isRecurring,
      scheduleId: isRecurring ? '1' : null,
      status: status,
    );

TaskListEntry _entry({
  required Task task,
  DateTime? occurrenceAt,
  String status = 'pending',
  DateTime? resolvedAt,
}) =>
    TaskListEntry(
      task: task,
      occurrenceAt: occurrenceAt,
      status: status,
      priority: 'medium',
      subtasks: const [],
      isVirtual: true,
      resolvedAt: resolvedAt,
    );

void main() {
  final today = DateTime(2026, 6, 7);

  group('classifyTaskForBucket', () {
    test('unplanned when no dates', () {
      expect(
        classifyTaskForBucket(_task(id: '1', name: 'A'), today),
        TaskBucket.unplanned,
      );
    });

    test('overdue when deadline before today', () {
      expect(
        classifyTaskForBucket(
          _task(
            id: '1',
            name: 'A',
            deadline: DateTime(2026, 6, 6),
          ),
          today,
        ),
        TaskBucket.overdue,
      );
    });

    test('deadline yesterday is overdue not today', () {
      final bucket = classifyTaskForBucket(
        _task(
          id: '1',
          name: 'A',
          deadline: DateTime(2026, 6, 6),
          plannedAt: DateTime(2026, 6, 1),
        ),
        today,
      );
      expect(bucket, TaskBucket.overdue);
    });

    test('planned last week without deadline is today', () {
      expect(
        classifyTaskForBucket(
          _task(
            id: '1',
            name: 'A',
            plannedAt: DateTime(2026, 6, 1),
          ),
          today,
        ),
        TaskBucket.today,
      );
    });

    test('future dated task is excluded', () {
      expect(
        classifyTaskForBucket(
          _task(
            id: '1',
            name: 'A',
            plannedAt: DateTime(2026, 6, 10),
          ),
          today,
        ),
        isNull,
      );
    });

    test('completed task is excluded', () {
      expect(
        classifyTaskForBucket(
          _task(
            id: '1',
            name: 'A',
            deadline: DateTime(2026, 6, 6),
            status: 'completed',
          ),
          today,
        ),
        isNull,
      );
    });
  });

  group('classifyEntryForBucket', () {
    test('recurring past occurrence without deadline is today', () {
      expect(
        classifyEntryForBucket(
          _entry(
            task: _task(id: '1', name: 'A', isRecurring: true),
            occurrenceAt: DateTime(2026, 6, 1),
          ),
          today,
        ),
        TaskBucket.today,
      );
    });
  });

  group('completed today helpers', () {
    test('task completed today is included', () {
      expect(
        taskCompletedOnLocalDay(
          _task(
            id: '1',
            name: 'A',
            status: 'completed',
            updatedAt: DateTime(2026, 6, 7, 18),
          ),
          today,
        ),
        isTrue,
      );
    });

    test('task completed yesterday is excluded', () {
      expect(
        taskCompletedOnLocalDay(
          _task(
            id: '1',
            name: 'A',
            status: 'completed',
            updatedAt: DateTime(2026, 6, 6, 18),
          ),
          today,
        ),
        isFalse,
      );
    });

    test('entry completed today uses resolvedAt', () {
      expect(
        taskEntryCompletedOnLocalDay(
          _entry(
            task: _task(id: '1', name: 'A', isRecurring: true),
            occurrenceAt: DateTime(2026, 6, 1),
            status: 'completed',
            resolvedAt: DateTime(2026, 6, 7, 9),
          ),
          today,
        ),
        isTrue,
      );
    });
  });

  group('computeTaskBucketSummary', () {
    test('empty tasks yields empty summary', () async {
      final summary = await computeTaskBucketSummary(
        tasks: const [],
        builder: TaskListBuilder(_FakeApi()),
      );
      expect(summary.count(TaskBucket.overdue), 0);
      expect(summary.count(TaskBucket.today), 0);
      expect(summary.count(TaskBucket.unplanned), 0);
      expect(summary.count(TaskBucket.completed), 0);
    });

    test('unplanned tasks counted without builder network', () async {
      final summary = await computeTaskBucketSummary(
        tasks: [_task(id: '1', name: 'Inbox')],
        builder: TaskListBuilder(_FakeApi()),
      );
      expect(summary.count(TaskBucket.unplanned), 1);
      expect(summary.unplanned.single.task.name, 'Inbox');
    });

    test('task completed today is counted in completed bucket', () async {
      final summary = await computeTaskBucketSummary(
        tasks: [
          _task(
            id: '1',
            name: 'Done today',
            status: 'completed',
            updatedAt: DateTime(2026, 6, 7, 12),
            plannedAt: DateTime(2026, 6, 5),
          ),
        ],
        builder: TaskListBuilder(_FakeApi()),
        now: today,
      );
      expect(summary.count(TaskBucket.completed), 1);
      expect(summary.completed.single.task.name, 'Done today');
      expect(summary.count(TaskBucket.today), 0);
    });
  });
}

class _FakeApi implements ApiClientService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
