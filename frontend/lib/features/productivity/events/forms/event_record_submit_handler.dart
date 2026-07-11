import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/companion_record_hydration.dart';
import 'package:frontend/core/scheduling/schedule_api.dart';
import 'package:frontend/features/productivity/events/models/event.dart';

import 'package:frontend/core/scheduling/schedule_form_values.dart';

/// Loads event + linked schedule on edit; submits via [RecordBloc].
///
/// Schedule exclusions are applied after save via `PUT /schedules/{id}/exclusions`.
class EventRecordSubmitHandler extends FormSubmitHandler {
  EventRecordSubmitHandler({
    required this.recordBloc,
    required this.apiClient,
    this.recordId,
    this.preloadedEvent,
  });

  final RecordBloc recordBloc;
  final ApiClientService apiClient;
  final RecordId? recordId;
  final Event? preloadedEvent;

  late final RecordSubmitHandler _delegate = RecordSubmitHandler(
    recordBloc: recordBloc,
    recordType: 'events',
    recordId: recordId,
    toRecord: (values) => Event.fromFormValues(values, id: recordId),
    fromRecord: (record) => (record as Event).toFormValues(),
  );

  @override
  bool get canHydrate => recordId != null;

  @override
  Future<Map<String, dynamic>> hydrate() async {
    if (recordId == null) return {};

    final eventValues = preloadedEvent != null
        ? preloadedEvent!.toFormValues()
        : await hydrateRecordValues(
            recordBloc: recordBloc,
            recordType: 'events',
            recordId: recordId!,
            fromRecord: (record) => (record as Event).toFormValues(),
          );

    final scheduleId =
        eventValues[TaskScheduleFormKeys.existingScheduleId]?.toString();
    if (scheduleId == null || scheduleId.isEmpty) {
      return {
        ...eventValues,
        ...TaskScheduleFormValues.defaultCreateValues(),
      };
    }

    final scheduleRecord = await loadScheduleRecord(
      recordBloc: recordBloc,
      scheduleId: scheduleId,
    );
    if (scheduleRecord == null) {
      return {
        ...eventValues,
        ...TaskScheduleFormValues.defaultCreateValues(),
        TaskScheduleFormKeys.existingScheduleId: scheduleId,
      };
    }

    final scheduleValues = TaskScheduleFormValues.fromScheduleResponse(
      scheduleRecord.toJson(),
    );
    final mode = scheduleValues.repeatType == TaskRepeatType.none
        ? TaskScheduleMode.off
        : TaskScheduleMode.repeating;

    final merged = {
      ...eventValues,
      ...scheduleValues.toFormMap(),
      TaskScheduleFormKeys.scheduleMode: mode,
      TaskScheduleFormKeys.originalScheduleId: scheduleId,
    };

    if (mode == TaskScheduleMode.repeating) {
      merged.remove(TaskScheduleFormKeys.existingScheduleId);
    } else {
      merged[TaskScheduleFormKeys.existingScheduleId] = scheduleId;
    }

    return merged;
  }

  @override
  Future<FormSubmitResult> submit(Map<String, dynamic> values) async {
    final exclusions = TaskScheduleFormValues.fromFormMap(values).exclusions;
    final result = await _delegate.submit(values);
    if (!result.success) return result;

    try {
      await _applySchedulePostSteps(values, result, exclusions);
      final eventId = _resolveEventId(result);
      if (eventId != null) {
        recordBloc.add(
          GetRecordRequested(recordType: 'events', recordId: eventId),
        );
        recordBloc.remoteCoordinator?.refreshQueryRecords(
          const RecordQuery(recordType: 'events', limit: 50),
        );
      }
      return result;
    } catch (error) {
      return FormSubmitResult.failure(error: error.toString());
    }
  }

  String? _resolveEventId(FormSubmitResult result) {
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

  @override
  void dispose() => _delegate.dispose();
}
