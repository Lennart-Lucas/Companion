import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/services/task_list_builder.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';

Task _task({
  required String id,
  required String name,
  DateTime? plannedAt,
  DateTime? deadline,
  bool isRecurring = false,
  DateTime? updatedAt,
}) =>
    Task(
      id: id,
      name: name,
      plannedAt: plannedAt,
      deadline: deadline,
      isRecurring: isRecurring,
      scheduleId: isRecurring ? '1' : null,
      updatedAt: updatedAt,
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
  group('taskListNonRecurringIsVisible', () {
    test('requires planned or deadline', () {
      expect(taskListNonRecurringIsVisible(_task(id: '1', name: 'A')), isFalse);
      expect(
        taskListNonRecurringIsVisible(
          _task(id: '1', name: 'A', plannedAt: DateTime(2026, 6, 1)),
        ),
        isTrue,
      );
      expect(
        taskListNonRecurringIsVisible(
          _task(id: '1', name: 'A', deadline: DateTime(2026, 6, 1)),
        ),
        isTrue,
      );
    });
  });

  group('applyTaskListDisplayRules', () {
    final now = DateTime(2026, 6, 7, 12);

    test('open non-recurring drifts from past planned date to today', () {
      final task = _task(
        id: '1',
        name: 'A',
        plannedAt: DateTime(2026, 6, 1),
      );
      final result = applyTaskListDisplayRules(
        _entry(task: task, occurrenceAt: task.plannedAt),
        now: now,
      );

      expect(result.displayAt, DateTime(2026, 6, 7));
      expect(result.isPastDue, isFalse);
    });

    test('open recurring drifts from past repeat date to today', () {
      final task = _task(id: '1', name: 'A', isRecurring: true);
      final result = applyTaskListDisplayRules(
        _entry(task: task, occurrenceAt: DateTime(2026, 6, 1)),
        now: now,
      );

      expect(result.displayAt, DateTime(2026, 6, 7));
      expect(result.isPastDue, isTrue);
    });

    test('future open task stays on scheduled date', () {
      final task = _task(
        id: '1',
        name: 'A',
        plannedAt: DateTime(2026, 6, 10),
      );
      final result = applyTaskListDisplayRules(
        _entry(task: task, occurrenceAt: task.plannedAt),
        now: now,
      );

      expect(result.displayAt, task.plannedAt);
      expect(result.isPastDue, isFalse);
    });

    test('completed task stays on resolved date not today', () {
      final task = _task(
        id: '1',
        name: 'A',
        plannedAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 5, 15),
      );
      final result = applyTaskListDisplayRules(
        _entry(
          task: task,
          occurrenceAt: task.plannedAt,
          status: 'completed',
          resolvedAt: DateTime(2026, 6, 5, 15),
        ),
        now: now,
      );

      expect(result.displayAt, DateTime(2026, 6, 5, 15));
      expect(result.isPastDue, isFalse);
    });

    test('non-recurring past due when deadline passed', () {
      final task = _task(
        id: '1',
        name: 'A',
        plannedAt: DateTime(2026, 6, 1),
        deadline: DateTime(2026, 6, 5),
      );
      final result = applyTaskListDisplayRules(
        _entry(task: task, occurrenceAt: task.plannedAt),
        now: now,
      );

      expect(result.displayAt, DateTime(2026, 6, 7));
      expect(result.isPastDue, isTrue);
    });

    test('completed task has no past due chip', () {
      final task = _task(
        id: '1',
        name: 'A',
        isRecurring: true,
        updatedAt: DateTime(2026, 6, 7),
      );
      final result = applyTaskListDisplayRules(
        _entry(
          task: task,
          occurrenceAt: DateTime(2026, 6, 1),
          status: 'completed',
          resolvedAt: DateTime(2026, 6, 7),
        ),
        now: now,
      );

      expect(result.isPastDue, isFalse);
    });

    test('preserves scheduled time-of-day when drifting', () {
      final task = _task(
        id: '1',
        name: 'A',
        plannedAt: DateTime(2026, 6, 1, 14, 30),
      );
      final result = applyTaskListDisplayRules(
        _entry(task: task, occurrenceAt: task.plannedAt),
        now: now,
      );

      expect(result.displayAt, DateTime(2026, 6, 7, 14, 30));
    });
  });

  group('taskListEntryDisplayInHorizon', () {
    final now = DateTime(2026, 6, 7, 12);

    test('includes drifted overdue task when today is in horizon', () {
      final horizon = TaskListHorizon.forLocalDays(
        DateTime(2026, 6, 5),
        DateTime(2026, 6, 10),
      );
      final task = _task(
        id: '1',
        name: 'A',
        plannedAt: DateTime(2026, 5, 1),
      );
      final entry = applyTaskListDisplayRules(
        _entry(task: task, occurrenceAt: task.plannedAt),
        now: now,
      );

      expect(taskListEntryDisplayInHorizon(entry, horizon), isTrue);
    });

    test('excludes drifted task when today is outside horizon', () {
      final horizon = TaskListHorizon.forLocalDays(
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 5),
      );
      final task = _task(
        id: '1',
        name: 'A',
        plannedAt: DateTime(2026, 5, 1),
      );
      final entry = applyTaskListDisplayRules(
        _entry(task: task, occurrenceAt: task.plannedAt),
        now: now,
      );

      expect(taskListEntryDisplayInHorizon(entry, horizon), isFalse);
    });
  });
}
