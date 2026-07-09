import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/http/companion_api_errors.dart';
import 'package:frontend/core/records/companion_record_hydration.dart';
import 'package:frontend/features/productivity/models/goal_milestone.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_schedule.dart';

/// Loads goal + linked schedule on edit; submits via [RecordBloc].
///
/// Milestone templates on update are synced with `PUT /goals/{id}/milestones`.
class GoalRecordSubmitHandler extends FormSubmitHandler {
  GoalRecordSubmitHandler({
    required this.recordBloc,
    required this.apiClient,
    this.recordId,
    this.preloadedGoal,
  });

  final RecordBloc recordBloc;
  final ApiClientService apiClient;
  final RecordId? recordId;
  final Goal? preloadedGoal;

  static const _goalsQuery = RecordQuery(recordType: 'goals', limit: 50);

  late final RecordSubmitHandler _delegate = RecordSubmitHandler(
    recordBloc: recordBloc,
    recordType: 'goals',
    recordId: recordId,
    toRecord: (values) => Goal.fromFormValues(values, id: recordId),
    fromRecord: (record) => (record as Goal).toFormValues(),
  );

  @override
  bool get canHydrate => recordId != null;

  @override
  Future<Map<String, dynamic>> hydrate() async {
    if (recordId == null) return {};

    final scheduleId = preloadedGoal?.scheduleId;
    final scheduleFuture = (scheduleId != null && scheduleId.isNotEmpty)
        ? loadScheduleRecord(recordBloc: recordBloc, scheduleId: scheduleId)
        : null;

    final goalValues = await hydrateRecordValues(
      recordBloc: recordBloc,
      recordType: 'goals',
      recordId: recordId!,
      fromRecord: (record) => (record as Goal).toFormValues(),
    );

    final resolvedScheduleId =
        scheduleId ?? goalValues['existing_schedule_id']?.toString();
    if (resolvedScheduleId == null || resolvedScheduleId.isEmpty) {
      return {
        ...goalValues,
        ...TaskScheduleFormValues.defaultCreateValues(),
        TaskScheduleFormKeys.repeatEnabled: true,
      };
    }

    final scheduleRecord = scheduleFuture != null
        ? await scheduleFuture
        : await loadScheduleRecord(
            recordBloc: recordBloc,
            scheduleId: resolvedScheduleId,
          );
    if (scheduleRecord == null) {
      return {
        ...goalValues,
        ...TaskScheduleFormValues.defaultCreateValues(),
        TaskScheduleFormKeys.repeatEnabled: true,
      };
    }

    final scheduleValues = TaskScheduleFormValues.fromScheduleResponse(
      scheduleRecord.toJson(),
    );

    return TaskScheduleFormValues.mergeAnchorOnlyScheduleFormValues(
      entityValues: goalValues,
      scheduleFormValues: scheduleValues.toFormMap(),
      existingScheduleId: resolvedScheduleId,
    );
  }

  @override
  Future<FormSubmitResult> submit(Map<String, dynamic> values) async {
    final milestonesPayload = GoalMilestoneFormValues.toApiPayload(
      values[GoalMilestoneFormKeys.milestones],
    );

    final result = await _delegate.submit(values);
    if (!result.success) return result;

    final id = _resolveGoalId(result);
    if (id == null) return result;

    try {
      if (recordId != null) {
        await _replaceMilestones(id, milestonesPayload);
      }
      recordBloc.add(GetRecordRequested(recordType: 'goals', recordId: id));
      recordBloc.remoteCoordinator?.refreshQueryRecords(_goalsQuery);
      return result;
    } catch (error) {
      final message = _formatSubmitError(error);
      if (recordId != null) {
        return FormSubmitResult.failure(
          error: 'Goal updated, but milestones could not be saved: $message',
        );
      }
      return FormSubmitResult.failure(error: message);
    }
  }

  String? _resolveGoalId(FormSubmitResult result) {
    if (recordId != null) return recordId;
    final data = result.data;
    if (data is Map<String, dynamic>) {
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  Future<void> _replaceMilestones(
    RecordId goalId,
    List<Map<String, dynamic>> milestones,
  ) async {
    final offline = CompanionAnvilApp.instance;
    if (!offline.connectivity.isOnline) {
      await offline.offlineTaskContext.enqueueApiCall(
        method: 'PUT',
        path: '/goals/$goalId/milestones',
        body: {'milestones': milestones},
      );
      return;
    }

    final response = await apiClient.put(
      '/goals/$goalId/milestones',
      body: {'milestones': milestones},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        formatCompanionApiError(
          statusCode: response.statusCode,
          body: response.body,
          action: 'Save milestones',
        ),
      );
    }
  }

  String _formatSubmitError(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }

  @override
  void dispose() => _delegate.dispose();
}
