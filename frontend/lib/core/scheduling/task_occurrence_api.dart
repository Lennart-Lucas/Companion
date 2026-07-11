import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/features/productivity/tasks/models/task_occurrence.dart';

/// REST client for task occurrence endpoints.
class TaskOccurrenceApi {
  TaskOccurrenceApi(this._api);

  final ApiClientService _api;

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$action failed: HTTP ${response.statusCode}');
    }
  }

  Future<List<TaskOccurrence>> listOccurrences(
    String taskId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 200,
  }) async {
    final fromParam = Uri.encodeQueryComponent(from.toUtc().toIso8601String());
    final toParam = Uri.encodeQueryComponent(to.toUtc().toIso8601String());
    final response = await _api.get(
      '/tasks/$taskId/occurrences?from=$fromParam&to=$toParam&max_count=$maxCount',
    );
    _ensureSuccess(response, 'List task occurrences');
    final items = response.bodyAsMap['items'];
    if (items is! List) return [];
    return [
      for (final item in items)
        if (item is Map)
          TaskOccurrence.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<TaskOccurrence> patchOccurrence(
    String taskId,
    String occurrenceId, {
    String? status,
    String? priority,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (priority != null) body['priority'] = priority;

    final response = await _api.patch(
      '/tasks/$taskId/occurrences/$occurrenceId',
      body: body,
    );
    _ensureSuccess(response, 'Update occurrence');
    return TaskOccurrence.fromJson(response.bodyAsMap);
  }

  Future<void> patchOccurrenceSubtask(
    String taskId,
    String occurrenceId,
    String subtaskId, {
    required bool completed,
  }) async {
    final response = await _api.patch(
      '/tasks/$taskId/occurrences/$occurrenceId/subtasks/$subtaskId',
      body: {'completed': completed},
    );
    _ensureSuccess(response, 'Update occurrence subtask');
  }
}
