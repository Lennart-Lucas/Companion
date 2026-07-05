/// A materialized task occurrence with per-instance status and subtasks.
class TaskOccurrence {
  const TaskOccurrence({
    required this.id,
    required this.occurrenceAt,
    required this.status,
    required this.priority,
    this.subtasks = const [],
  });

  final String id;
  final DateTime occurrenceAt;
  final String status;
  final String priority;
  final List<TaskOccurrenceSubtask> subtasks;

  factory TaskOccurrence.fromJson(Map<String, dynamic> json) {
    final subtasksRaw = json['subtasks'];
    final subtasks = <TaskOccurrenceSubtask>[];
    if (subtasksRaw is List) {
      for (final item in subtasksRaw) {
        if (item is Map) {
          subtasks.add(
            TaskOccurrenceSubtask.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return TaskOccurrence(
      id: json['id']?.toString() ?? '',
      occurrenceAt: _dateTimeFromJson(json['occurrence_at']) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'pending',
      priority: json['priority']?.toString() ?? 'medium',
      subtasks: subtasks,
    );
  }
}

class TaskOccurrenceSubtask {
  const TaskOccurrenceSubtask({
    required this.id,
    required this.title,
    required this.completed,
  });

  final String id;
  final String title;
  final bool completed;

  factory TaskOccurrenceSubtask.fromJson(Map<String, dynamic> json) {
    return TaskOccurrenceSubtask(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      completed: json['completed'] == true,
    );
  }
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
