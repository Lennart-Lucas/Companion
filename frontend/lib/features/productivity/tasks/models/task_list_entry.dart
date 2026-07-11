import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/tasks/models/task_subtask.dart';

/// Checklist row state for a task list entry (template + completion).
class TaskListSubtaskItem {
  const TaskListSubtaskItem({
    required this.subtaskId,
    required this.title,
    required this.completed,
  });

  final String subtaskId;
  final String title;
  final bool completed;

  TaskListSubtaskItem copyWith({bool? completed}) => TaskListSubtaskItem(
        subtaskId: subtaskId,
        title: title,
        completed: completed ?? this.completed,
      );

  /// Parses checklist rows from a task occurrence API payload.
  static List<TaskListSubtaskItem> fromOccurrenceJson(dynamic raw) {
    if (raw is! List) return const [];
    final items = <TaskListSubtaskItem>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final id = row['id']?.toString();
      final title = row['title']?.toString();
      if (id == null || title == null) continue;
      items.add(
        TaskListSubtaskItem(
          subtaskId: id,
          title: title,
          completed: row['completed'] == true,
        ),
      );
    }
    return items;
  }
}

/// One row in the expanded tasks list (task or schedule occurrence).
class TaskListEntry {
  const TaskListEntry({
    required this.task,
    required this.status,
    required this.priority,
    required this.subtasks,
    required this.isVirtual,
    this.occurrenceAt,
    this.occurrenceId,
    this.resolvedAt,
    this.displayAt,
    this.isPastDue = false,
  });

  final Task task;
  final DateTime? occurrenceAt;
  final String? occurrenceId;
  final String status;
  final String priority;
  final List<TaskListSubtaskItem> subtasks;
  final bool isVirtual;
  final DateTime? resolvedAt;
  final DateTime? displayAt;
  final bool isPastDue;

  bool get isRecurringInstance => task.isRecurring && occurrenceAt != null;

  String get listKey {
    if (occurrenceAt != null) {
      final at = occurrenceAt!.toUtc();
      return '${task.id}:${at.toIso8601String()}';
    }
    return '${task.id}:single';
  }

  TaskListEntry copyWith({
    String? status,
    String? priority,
    List<TaskListSubtaskItem>? subtasks,
    String? occurrenceId,
    bool? isVirtual,
    DateTime? resolvedAt,
    DateTime? displayAt,
    bool? isPastDue,
  }) =>
      TaskListEntry(
        task: task,
        occurrenceAt: occurrenceAt,
        occurrenceId: occurrenceId ?? this.occurrenceId,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        subtasks: subtasks ?? this.subtasks,
        isVirtual: isVirtual ?? this.isVirtual,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        displayAt: displayAt ?? this.displayAt,
        isPastDue: isPastDue ?? this.isPastDue,
      );

  static List<TaskListSubtaskItem> defaultSubtasks(Task task) {
    final sorted = List<TaskSubtaskTemplate>.from(task.subtasks)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [
      for (final t in sorted)
        if (t.id != null)
          TaskListSubtaskItem(
            subtaskId: t.id!,
            title: t.title,
            completed: false,
          ),
    ];
  }
}
