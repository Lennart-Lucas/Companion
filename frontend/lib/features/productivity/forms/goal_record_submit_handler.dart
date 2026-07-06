import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/companion_record_hydration.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_schedule.dart';

/// Loads goal + linked schedule on edit; submits via [RecordBloc].
class GoalRecordSubmitHandler extends FormSubmitHandler {
  GoalRecordSubmitHandler({
    required this.recordBloc,
    this.recordId,
    this.preloadedGoal,
  });

  final RecordBloc recordBloc;
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
    final result = await _delegate.submit(values);
    if (!result.success) return result;

    final id = _resolveGoalId(result);
    if (id == null) return result;

    recordBloc.add(GetRecordRequested(recordType: 'goals', recordId: id));
    recordBloc.remoteCoordinator?.refreshQueryRecords(_goalsQuery);
    return result;
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

  @override
  void dispose() => _delegate.dispose();
}
