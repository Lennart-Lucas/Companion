import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/companion_record_hydration.dart';
import 'package:frontend/core/scheduling/schedule_api.dart';
import 'package:frontend/features/productivity/tasks/forms/task_planned_deadline_fields.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/core/scheduling/schedule_form_values.dart';
import 'package:frontend/features/productivity/tasks/models/task_subtask.dart';

/// Loads task + linked schedule on edit; submits via [RecordBloc].
///
/// Checklist templates on update are synced with `PUT /tasks/{id}/subtasks`.
/// Schedule exclusions are applied after save via `PUT /schedules/{id}/exclusions`.
class TaskRecordSubmitHandler extends FormSubmitHandler {
  TaskRecordSubmitHandler({
    required this.recordBloc,
    required this.apiClient,
    this.recordId,
  });

  final RecordBloc recordBloc;
  final ApiClientService apiClient;
  final RecordId? recordId;

  late final RecordSubmitHandler _delegate = RecordSubmitHandler(
    recordBloc: recordBloc,
    recordType: 'tasks',
    recordId: recordId,
    toRecord: (values) => Task.fromFormValues(values, id: recordId),
    fromRecord: (record) => (record as Task).toFormValues(),
  );

  @override
  bool get canHydrate => recordId != null;

  @override
  Future<Map<String, dynamic>> hydrate() async {
    if (recordId == null) return {};

    final taskValues = await hydrateRecordValues(
      recordBloc: recordBloc,
      recordType: 'tasks',
      recordId: recordId!,
      fromRecord: (record) => (record as Task).toFormValues(),
    );

    final scheduleId =
        taskValues[TaskScheduleFormKeys.existingScheduleId]?.toString();
    if (scheduleId == null || scheduleId.isEmpty) {
      return {
        ...taskValues,
        ...TaskScheduleFormValues.defaultCreateValues(),
      };
    }

    final scheduleRecord = await loadScheduleRecord(
      recordBloc: recordBloc,
      scheduleId: scheduleId,
    );
    if (scheduleRecord == null) {
      return {
        ...taskValues,
        ...TaskScheduleFormValues.defaultCreateValues(),
        TaskScheduleFormKeys.existingScheduleId: scheduleId,
      };
    }

    final scheduleValues = TaskScheduleFormValues.fromScheduleResponse(
      scheduleRecord.toJson(),
    );

    final merged = {
      ...taskValues,
      ...scheduleValues.toFormMap(),
      TaskScheduleFormKeys.originalScheduleId: scheduleId,
    };

    if (scheduleValues.mode == TaskScheduleMode.repeating ||
        scheduleValues.mode == TaskScheduleMode.oneOff) {
      merged.remove(TaskScheduleFormKeys.existingScheduleId);
    } else {
      merged[TaskScheduleFormKeys.existingScheduleId] = scheduleId;
    }

    if (scheduleValues.mode == TaskScheduleMode.oneOff) {
      final anchor = scheduleValues.anchor ?? scheduleValues.startDate;
      if (anchor != null) {
        merged[taskDeadlineFieldKey] = anchor;
      }
    }

    return merged;
  }

  @override
  Future<FormSubmitResult> submit(Map<String, dynamic> values) async {
    final subtasksPayload =
        TaskSubtaskFormValues.toApiPayload(values[TaskSubtaskFormKeys.subtasks]);
    final exclusions = TaskScheduleFormValues.fromFormMap(values).exclusions;

    final result = await _delegate.submit(values);
    if (!result.success) return result;

    final taskId = _resolveTaskId(result);
    if (taskId == null) return result;

    try {
      if (recordId != null) {
        await _replaceSubtasks(taskId, subtasksPayload);
      }
      await _applySchedulePostSteps(values, result, exclusions);
      recordBloc.add(GetRecordRequested(recordType: 'tasks', recordId: taskId));
      recordBloc.remoteCoordinator?.refreshQueryRecords(
        const RecordQuery(recordType: 'tasks', limit: 50),
      );
      return result;
    } catch (error) {
      return FormSubmitResult.failure(error: error.toString());
    }
  }

  String? _resolveTaskId(FormSubmitResult result) {
    if (recordId != null) return recordId;
    final data = result.data;
    if (data is Map<String, dynamic>) {
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  String? _resolveScheduleId(
    Map<String, dynamic> values,
    FormSubmitResult result,
  ) {
    final linked =
        values[TaskScheduleFormKeys.existingScheduleId]?.toString().trim();
    if (linked != null && linked.isNotEmpty) return linked;

    final data = result.data;
    if (data is Map<String, dynamic>) {
      final nested = data['data'];
      final map = nested is Map
          ? Map<String, dynamic>.from(nested)
          : data;
      final scheduleId = map['schedule_id']?.toString();
      if (scheduleId != null && scheduleId.isNotEmpty) return scheduleId;
    }
    return null;
  }

  Future<void> _applySchedulePostSteps(
    Map<String, dynamic> values,
    FormSubmitResult result,
    List<DateTime> exclusions,
  ) async {
    if (exclusions.isEmpty) return;

    final scheduleId = _resolveScheduleId(values, result);
    if (scheduleId == null) return;

    final offline = CompanionAnvilApp.instance;
    if (!offline.connectivity.isOnline) {
      await offline.offlineTaskContext.enqueueApiCall(
        method: 'PUT',
        path: '/schedules/$scheduleId/exclusions',
        body: {
          'dates': exclusions
              .map(
                (d) => DateTime(d.year, d.month, d.day)
                    .toIso8601String()
                    .split('T')
                    .first,
              )
              .toList(),
        },
      );
      return;
    }

    await ScheduleApi(apiClient).putExclusions(scheduleId, exclusions);
  }

  Future<void> _replaceSubtasks(
    RecordId taskId,
    List<Map<String, dynamic>> subtasks,
  ) async {
    final offline = CompanionAnvilApp.instance;
    if (!offline.connectivity.isOnline) {
      await offline.offlineTaskContext.enqueueApiCall(
        method: 'PUT',
        path: '/tasks/$taskId/subtasks',
        body: {'subtasks': subtasks},
      );
      return;
    }
    final response = await apiClient.put(
      '/tasks/$taskId/subtasks',
      body: {'subtasks': subtasks},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to save checklist: HTTP ${response.statusCode}',
      );
    }
  }

  @override
  void dispose() => _delegate.dispose();
}
