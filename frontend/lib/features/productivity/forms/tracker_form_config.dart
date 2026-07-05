import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/tracker_form_fields.dart';
import 'package:frontend/features/productivity/forms/tracker_record_submit_handler.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_schedule.dart';

num? _parseTargetValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return num.tryParse(trimmed);
  }
  return null;
}

String? _validateTrackerTypeFields(Map<String, dynamic> values) {
  final checkInType =
      values['check_in_type']?.toString() ?? TrackerCheckInType.task;
  final targetRaw = values['target'];
  final unit = (values['unit'] as String? ?? '').trim();

  if (checkInType == TrackerCheckInType.task) {
    if (targetRaw != null && targetRaw.toString().trim().isNotEmpty) {
      return 'Task check-in type cannot have a target';
    }
    if (unit.isNotEmpty) {
      return 'Task check-in type cannot have a unit';
    }
    return null;
  }

  if (checkInType == TrackerCheckInType.count) {
    if (targetRaw == null || targetRaw.toString().trim().isEmpty) {
      return 'Count check-in type requires a target';
    }
    if (unit.isEmpty) {
      return 'Count check-in type requires a unit';
    }
    return null;
  }

  if (checkInType == TrackerCheckInType.duration) {
    final target = _parseTargetValue(targetRaw);
    if (target == null || target <= 0) {
      return 'Duration check-in type requires a target duration';
    }
    if (unit.isNotEmpty) {
      return 'Duration check-in type cannot have a unit';
    }
    return null;
  }

  return null;
}

String? _validateEndDate(Map<String, dynamic> values) {
  final schedule = TaskScheduleFormValues.fromFormMap({
    ...values,
    TaskScheduleFormKeys.repeatEnabled: true,
  });
  final anchor = schedule.anchor;
  final end = values['end_date'];
  if (anchor == null || end is! DateTime) {
    return null;
  }
  final startDay = DateTime(anchor.year, anchor.month, anchor.day);
  final endDay = DateTime(end.year, end.month, end.day);
  if (!endDay.isAfter(startDay)) {
    return 'End date must be after the schedule start date';
  }
  return null;
}

/// [AnvilFormConfig] for creating or editing a tracker.
AnvilFormConfig buildTrackerFormConfig(
  RecordBloc recordBloc, {
  RecordId? recordId,
  Tracker? preloadedTracker,
}) {
  final isEdit = recordId != null;

  return AnvilFormConfig(
    formKey: isEdit ? 'edit_tracker' : 'create_tracker',
    steps: const ['main'],
    pages: {
      'main': AnvilFormPage(
        builder: (context, state) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const TrackerFormFields(),
            ),
          ),
        ),
      ),
    },
    initialValues: isEdit
        ? const {}
        : {
            'check_in_type': TrackerCheckInType.task,
            'habit_direction': TrackerHabitDirection.build,
            ...TaskScheduleFormValues.defaultCreateValues(),
            TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
            TaskScheduleFormKeys.repeatEnabled: true,
          },
    validationRules: [
      AnvilFormValidationRule(
        fieldKey: 'name',
        validate: (values) {
          final name = (values['name'] as String? ?? '').trim();
          if (name.isEmpty) return 'Name is required';
          return null;
        },
      ),
      AnvilFormValidationRule(
        fieldKey: 'end_date',
        validate: _validateEndDate,
      ),
      AnvilFormValidationRule(
        fieldKey: 'check_in_type',
        validate: _validateTrackerTypeFields,
      ),
      AnvilFormValidationRule(
        fieldKey: TaskScheduleFormKeys.repeatType,
        validate: TaskScheduleFormValues.validateRequired,
      ),
    ],
    submitHandler: TrackerRecordSubmitHandler(
      recordBloc: recordBloc,
      recordId: recordId,
      preloadedTracker: preloadedTracker,
    ),
  );
}
