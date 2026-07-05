import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/offline/offline_task_context.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';
import 'package:frontend/features/productivity/widgets/task_status_utils.dart';

abstract class TaskListTileActions {
  Future<TaskListEntry> cycleStatus(TaskListEntry entry);
  Future<TaskListEntry> toggleSubtask(
    TaskListEntry entry,
    String subtaskId,
    bool completed,
  );
  Future<void> copyTask(Task task);
  Future<void> deleteTask(String taskId);
  Future<void> deleteThisEntry(TaskListEntry entry);
  Future<void> deleteThisAndFuture(TaskListEntry entry);
}

class TaskListActions implements TaskListTileActions {
  TaskListActions(this._api, {OfflineTaskContext? offlineContext})
      : _offline = offlineContext;

  final ApiClientService _api;
  final OfflineTaskContext? _offline;

  @override
  Future<TaskListEntry> cycleStatus(TaskListEntry entry) async {
    final next = nextTaskStatus(entry.status);
    if (!entry.task.isRecurring) {
      if (_offline?.isOffline == true) {
        await _offline!.enqueueApiCall(
          method: 'PATCH',
          path: '/tasks/${entry.task.id}',
          body: {'status': next},
        );
        return applyTaskListDisplayRules(
          entry.copyWith(
            status: next,
            isVirtual: false,
            resolvedAt: taskListStatusIsTerminal(next)
                ? DateTime.now().toUtc()
                : null,
          ),
        );
      }
      final response = await _api.patch(
        '/tasks/${entry.task.id}',
        body: {'status': next},
      );
      _ensureSuccess(response, 'Update task status');
      final updatedAt = _dateTimeFromJson(response.bodyAsMap['updated_at']);
      return applyTaskListDisplayRules(
        entry.copyWith(
          status: next,
          isVirtual: false,
          resolvedAt: taskListStatusIsTerminal(next)
              ? (updatedAt ?? entry.task.updatedAt)
              : null,
        ),
      );
    }

    final materialized = await _ensureOccurrence(entry);
    if (_offline?.isOffline == true) {
      await _offline!.enqueueApiCall(
        method: 'PATCH',
        path:
            '/tasks/${materialized.task.id}/occurrences/${materialized.occurrenceId}',
        body: {'status': next},
        dependsOn: materialized.occurrenceId?.startsWith('temp-') == true
            ? materialized.occurrenceId
            : null,
      );
      await _updateLocalOccurrence(materialized, status: next);
      return applyTaskListDisplayRules(
        materialized.copyWith(
          status: next,
          isVirtual: false,
          resolvedAt: taskListStatusIsTerminal(next)
              ? DateTime.now().toUtc()
              : null,
        ),
      );
    }
    final response = await _api.patch(
      '/tasks/${materialized.task.id}/occurrences/${materialized.occurrenceId}',
      body: {'status': next},
    );
    _ensureSuccess(response, 'Update occurrence status');
    final body = response.bodyAsMap;
    final updatedAt = _dateTimeFromJson(body['updated_at']);
    return applyTaskListDisplayRules(
      materialized.copyWith(
        status: next,
        isVirtual: false,
        resolvedAt: taskListStatusIsTerminal(next)
            ? (updatedAt ?? materialized.task.updatedAt)
            : null,
      ),
    );
  }

  @override
  Future<TaskListEntry> toggleSubtask(
    TaskListEntry entry,
    String subtaskId,
    bool completed,
  ) async {
    final clickedTitle = entry.subtasks
        .where((item) => item.subtaskId == subtaskId)
        .map((item) => item.title)
        .firstOrNull;
    final materialized = await _ensureOccurrence(entry, refreshSubtasks: true);
    final resolvedSubtaskId = _resolveSubtaskId(
      materialized,
      subtaskId,
      clickedTitle,
    );
    if (_offline?.isOffline == true) {
      await _offline!.enqueueApiCall(
        method: 'PATCH',
        path:
            '/tasks/${materialized.task.id}/occurrences/${materialized.occurrenceId}/subtasks/$resolvedSubtaskId',
        body: {'completed': completed},
      );
    } else {
      final response = await _api.patch(
        '/tasks/${materialized.task.id}/occurrences/${materialized.occurrenceId}/subtasks/$resolvedSubtaskId',
        body: {'completed': completed},
      );
      _ensureSuccess(response, 'Toggle checklist item');
    }

    final subtasks = [
      for (final item in materialized.subtasks)
        item.subtaskId == resolvedSubtaskId
            ? item.copyWith(completed: completed)
            : item,
    ];
    final updated = materialized.copyWith(subtasks: subtasks, isVirtual: false);
    await _updateLocalOccurrence(updated);
    return updated;
  }

  String _resolveSubtaskId(
    TaskListEntry entry,
    String requestedId,
    String? title,
  ) {
    if (entry.subtasks.any((item) => item.subtaskId == requestedId)) {
      return requestedId;
    }
    if (title != null) {
      for (final item in entry.subtasks) {
        if (item.title == title) return item.subtaskId;
      }
    }
    return requestedId;
  }

  Future<TaskListEntry> _ensureOccurrence(
    TaskListEntry entry, {
    bool refreshSubtasks = false,
  }) async {
    if (!refreshSubtasks && entry.occurrenceId != null) return entry;

    final at = entry.occurrenceAt ??
        entry.task.deadline ??
        entry.task.plannedAt ??
        DateTime.now().toUtc();

    if (_offline?.isOffline == true) {
      final tempId = 'temp-occ-${DateTime.now().millisecondsSinceEpoch}';
      final materialized = entry.copyWith(
        occurrenceId: tempId,
        isVirtual: false,
      );
      await _offline!.enqueueApiCall(
        method: 'POST',
        path: '/tasks/${entry.task.id}/occurrences',
        body: {'occurrence_at': at.toUtc().toIso8601String()},
      );
      await _updateLocalOccurrence(materialized);
      return materialized;
    }

    final response = await _api.post(
      '/tasks/${entry.task.id}/occurrences',
      body: {'occurrence_at': at.toUtc().toIso8601String()},
    );
    _ensureSuccess(response, 'Ensure occurrence');
    final body = response.bodyAsMap;
    final subtasks = TaskListSubtaskItem.fromOccurrenceJson(body['subtasks']);
    final resolvedSubtasks = subtasks.isNotEmpty
        ? subtasks
        : entry.subtasks;

    final materialized = entry.copyWith(
      occurrenceId: body['id']?.toString(),
      status: body['status']?.toString() ?? entry.status,
      priority: body['priority']?.toString() ?? entry.priority,
      subtasks: resolvedSubtasks,
      isVirtual: false,
    );
    await _updateLocalOccurrence(materialized);
    return materialized;
  }

  Future<void> _updateLocalOccurrence(
    TaskListEntry entry, {
    String? status,
  }) async {
    final offline = _offline;
    if (offline == null || entry.occurrenceId == null) return;
    final at = entry.occurrenceAt ?? DateTime.now().toUtc();
    final items = await offline.cache.loadOccurrences(entry.task.id);
    final nextStatus = status ?? entry.status;
    final row = {
      'id': entry.occurrenceId,
      'occurrence_at': at.toUtc().toIso8601String(),
      'status': nextStatus,
      'priority': entry.priority,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'subtasks': [
        for (final s in entry.subtasks)
          {
            'subtask_id': s.subtaskId,
            'title': s.title,
            'completed': s.completed,
          },
      ],
    };
    final filtered = items
        .where((item) => item['id']?.toString() != entry.occurrenceId)
        .toList();
    filtered.add(row);
    await offline.cache.saveOccurrences(entry.task.id, filtered);
  }

  @override
  Future<void> copyTask(Task task) async {
    final response = await _api.get('/tasks/${task.id}');
    _ensureSuccess(response, 'Fetch task');
    final data = Map<String, dynamic>.from(response.bodyAsMap);

    final createBody = <String, dynamic>{
      'name': '${data['name']} (copy)',
      'status': data['status'] ?? 'pending',
      'priority': data['priority'] ?? 'medium',
    };

    if (data['description'] != null) {
      createBody['description'] = data['description'];
    }
    if (data['planned_at'] != null) {
      createBody['planned_at'] = data['planned_at'];
    }
    if (data['deadline'] != null) {
      createBody['deadline'] = data['deadline'];
    }
    if (data['project_id'] != null) {
      createBody['project_id'] = data['project_id'];
    }
    if (data['goal_id'] != null) {
      createBody['goal_id'] = data['goal_id'];
    }

    final subtasks = data['subtasks'];
    if (subtasks is List && subtasks.isNotEmpty) {
      createBody['subtasks'] = [
        for (var i = 0; i < subtasks.length; i++)
          if (subtasks[i] is Map)
            {
              'title': (subtasks[i] as Map)['title'],
              'sort_order': i,
            },
      ];
    }

    if (data['is_recurring'] == true && data['schedule_id'] != null) {
      final scheduleResponse =
          await _api.get('/schedules/${data['schedule_id']}');
      _ensureSuccess(scheduleResponse, 'Fetch schedule');
      final schedule = scheduleResponse.bodyAsMap;
      createBody['schedule'] = _schedulePayloadFromResponse(schedule);
    }

    final createResponse = await _api.post('/tasks', body: createBody);
    _ensureSuccess(createResponse, 'Copy task');
  }

  Map<String, dynamic> _schedulePayloadFromResponse(Map<String, dynamic> s) {
    final map = <String, dynamic>{
      'dtstart': s['dtstart'] ?? s['anchor_at'],
      'timezone': s['timezone'],
    };
    if (s['rrule'] != null) map['rrule'] = s['rrule'];
    if (s['start_date'] != null) map['start_date'] = s['start_date'];
    if (s['end_date'] != null) map['end_date'] = s['end_date'];
    final rdates = s['rdates'] ?? s['specific_dates'];
    if (rdates is List && rdates.isNotEmpty) {
      map['rdates'] = [
        for (final row in rdates)
          if (row is Map)
            (row['occurrence_date'] ?? row['date']).toString().split('T').first,
      ];
    }
    return map;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    if (_offline?.isOffline == true) {
      await _offline!.enqueueApiCall(
        method: 'DELETE',
        path: '/tasks/$taskId',
      );
      return;
    }
    final response = await _api.delete('/tasks/$taskId');
    _ensureSuccess(response, 'Delete task');
  }

  @override
  Future<void> deleteThisEntry(TaskListEntry entry) async {
    final scheduleId = entry.task.scheduleId;
    final at = entry.occurrenceAt;
    if (scheduleId == null || at == null) {
      await deleteTask(entry.task.id);
      return;
    }

    if (_offline?.isOffline == true) {
      await _offline!.enqueueApiCall(
        method: 'POST',
        path: '/schedules/$scheduleId/exclusions/occurrence',
        body: {'occurrence_at': at.toUtc().toIso8601String()},
      );
      return;
    }
    final response = await _api.post(
      '/schedules/$scheduleId/exclusions/occurrence',
      body: {'occurrence_at': at.toUtc().toIso8601String()},
    );
    _ensureSuccess(response, 'Add schedule exclusion');
  }

  @override
  Future<void> deleteThisAndFuture(TaskListEntry entry) async {
    final scheduleId = entry.task.scheduleId;
    final at = entry.occurrenceAt;
    if (scheduleId == null || at == null) {
      await deleteTask(entry.task.id);
      return;
    }

    if (_offline?.isOffline == true) {
      await _offline!.enqueueApiCall(
        method: 'PATCH',
        path: '/schedules/$scheduleId',
        body: {
          'truncate_before_occurrence_at': at.toUtc().toIso8601String(),
        },
      );
      return;
    }
    final response = await _api.patch(
      '/schedules/$scheduleId',
      body: {
        'truncate_before_occurrence_at': at.toUtc().toIso8601String(),
      },
    );
    _ensureSuccess(response, 'Update schedule end date');
  }

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$action failed: HTTP ${response.statusCode}');
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
}
