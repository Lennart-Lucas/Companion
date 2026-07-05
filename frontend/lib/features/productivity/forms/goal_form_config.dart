import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/goal_form_fields.dart';
import 'package:frontend/features/productivity/forms/goal_record_submit_handler.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_schedule.dart';

String? _validateTargetAndUnit(Map<String, dynamic> values) {
  final targetRaw = values['target'];
  final unit = (values['unit'] as String? ?? '').trim();

  if (targetRaw == null || targetRaw.toString().trim().isEmpty) {
    return 'Target is required';
  }
  final target = targetRaw is num
      ? targetRaw
      : num.tryParse(targetRaw.toString().trim());
  if (target == null || target <= 0) {
    return 'Target must be greater than 0';
  }
  if (unit.isEmpty) {
    return 'Unit is required';
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

/// [AnvilFormConfig] for creating or editing a goal.
AnvilFormConfig buildGoalFormConfig(
  RecordBloc recordBloc, {
  RecordId? recordId,
  Goal? preloadedGoal,
}) {
  final isEdit = recordId != null;

  return AnvilFormConfig(
    formKey: isEdit ? 'edit_goal' : 'create_goal',
    steps: const ['main'],
    pages: {
      'main': AnvilFormPage(
        builder: (context, state) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const GoalFormFields(),
            ),
          ),
        ),
      ),
    },
    initialValues: isEdit
        ? const {}
        : {
            'goal_type': GoalType.count,
            'direction': GoalDirection.increasing,
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
        fieldKey: 'target',
        validate: _validateTargetAndUnit,
      ),
      AnvilFormValidationRule(
        fieldKey: 'end_date',
        validate: _validateEndDate,
      ),
      AnvilFormValidationRule(
        fieldKey: TaskScheduleFormKeys.repeatType,
        validate: TaskScheduleFormValues.validateRequired,
      ),
    ],
    submitHandler: GoalRecordSubmitHandler(
      recordBloc: recordBloc,
      recordId: recordId,
      preloadedGoal: preloadedGoal,
    ),
  );
}
