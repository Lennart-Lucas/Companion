import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/companion_record_hydration.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/core/scheduling/schedule_form_values.dart';

/// Loads tracker + linked schedule on edit; submits via [RecordBloc].
class TrackerRecordSubmitHandler extends FormSubmitHandler {
  TrackerRecordSubmitHandler({
    required this.recordBloc,
    this.recordId,
    this.preloadedTracker,
  });

  final RecordBloc recordBloc;
  final RecordId? recordId;
  final Tracker? preloadedTracker;

  late final RecordSubmitHandler _delegate = RecordSubmitHandler(
    recordBloc: recordBloc,
    recordType: 'trackers',
    recordId: recordId,
    toRecord: (values) => Tracker.fromFormValues(values, id: recordId),
    fromRecord: (record) => (record as Tracker).toFormValues(),
  );

  @override
  bool get canHydrate => recordId != null;

  @override
  Future<Map<String, dynamic>> hydrate() async {
    if (recordId == null) return {};

    final scheduleIdHint = preloadedTracker?.scheduleId;
    final scheduleFuture = (scheduleIdHint != null && scheduleIdHint.isNotEmpty)
        ? loadScheduleRecord(recordBloc: recordBloc, scheduleId: scheduleIdHint)
        : null;

    final trackerValues = await hydrateRecordValues(
      recordBloc: recordBloc,
      recordType: 'trackers',
      recordId: recordId!,
      fromRecord: (record) => (record as Tracker).toFormValues(),
    );

    final resolvedScheduleId =
        scheduleIdHint ?? trackerValues['existing_schedule_id']?.toString();
    if (resolvedScheduleId == null || resolvedScheduleId.isEmpty) {
      return {
        ...trackerValues,
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
        ...trackerValues,
        ...TaskScheduleFormValues.defaultCreateValues(),
        TaskScheduleFormKeys.repeatEnabled: true,
      };
    }

    final scheduleValues = TaskScheduleFormValues.fromScheduleResponse(
      scheduleRecord.toJson(),
    );

    return TaskScheduleFormValues.mergeAnchorOnlyScheduleFormValues(
      entityValues: trackerValues,
      scheduleFormValues: scheduleValues.toFormMap(),
      existingScheduleId: resolvedScheduleId,
    );
  }

  @override
  Future<FormSubmitResult> submit(Map<String, dynamic> values) async {
    final result = await _delegate.submit(values);
    if (!result.success) return result;

    final id = _resolveTrackerId(result);
    if (id == null) return result;

    recordBloc.add(
      GetRecordRequested(recordType: 'trackers', recordId: id),
    );
    final scheduleId = values['existing_schedule_id']?.toString();
    if (scheduleId != null && scheduleId.isNotEmpty) {
      recordBloc.add(
        GetRecordRequested(recordType: 'schedules', recordId: scheduleId),
      );
    }
    recordBloc.remoteCoordinator?.refreshQueryRecords(
      const RecordQuery(recordType: 'trackers', limit: 50),
    );
    return result;
  }

  String? _resolveTrackerId(FormSubmitResult result) {
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
