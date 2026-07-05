/// Checklist item template on a task (backend `task_subtasks`).
class TaskSubtaskTemplate {
  const TaskSubtaskTemplate({
    this.id,
    required this.title,
    this.sortOrder = 0,
  });

  final String? id;
  final String title;
  final int sortOrder;

  factory TaskSubtaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskSubtaskTemplate(
      id: json['id']?.toString(),
      title: json['title'] as String? ?? '',
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toApiJson(int sortOrder) => {
        'title': title.trim(),
        'sort_order': sortOrder,
      };
}

/// Form key and helpers for task checklist items.
abstract final class TaskSubtaskFormKeys {
  static const subtasks = 'subtasks';
}

abstract final class TaskSubtaskFormValues {
  static List<Map<String, dynamic>> emptyFormEntries() => [];

  static List<Map<String, dynamic>> templatesToFormEntries(
    List<TaskSubtaskTemplate> templates,
  ) {
    final sorted = List<TaskSubtaskTemplate>.from(templates)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [
      for (final item in sorted) {'title': item.title},
    ];
  }

  static List<TaskSubtaskTemplate> templatesFromJson(dynamic value) {
    if (value is! List) return const [];
    final items = <TaskSubtaskTemplate>[];
    for (final entry in value) {
      if (entry is Map) {
        items.add(
          TaskSubtaskTemplate.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
    }
    return items;
  }

  /// Builds API `subtasks` array; skips blank titles.
  static List<Map<String, dynamic>> toApiPayload(dynamic raw) {
    if (raw is! List) return [];
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map) continue;
      final title = (entry['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;
      items.add({'title': title, 'sort_order': items.length});
    }
    return items;
  }
}
