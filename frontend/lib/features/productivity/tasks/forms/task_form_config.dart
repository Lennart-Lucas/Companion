import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/tasks/forms/task_form_main_fields.dart';
import 'package:frontend/features/productivity/tasks/forms/task_record_submit_handler.dart';
import 'package:frontend/features/productivity/tasks/forms/task_schedule_fields.dart';
import 'package:frontend/features/productivity/tasks/forms/task_subtasks_field.dart';
import 'package:frontend/features/productivity/shared/widgets/transparent_form_panel.dart';
import 'package:frontend/core/scheduling/schedule_form_values.dart';
import 'package:frontend/features/productivity/tasks/models/task_subtask.dart';

String? _validateTaskParentExclusivity(Map<String, dynamic> values) {
  final project = (values['project_id']?.toString() ?? '').trim();
  final goal = (values['goal_id']?.toString() ?? '').trim();
  if (project.isNotEmpty && goal.isNotEmpty) {
    return 'Choose either a project or a goal, not both';
  }
  return null;
}

String? _validatePlannedBeforeDeadline(Map<String, dynamic> values) {
  final mode = TaskScheduleFormValues.modeFrom(values);
  if (!TaskScheduleMode.usesTaskDates(mode)) {
    return null;
  }
  final planned = values['planned_at'];
  final deadline = values['deadline'];
  if (planned is! DateTime || deadline is! DateTime) {
    return null;
  }
  if (planned.isAfter(deadline)) {
    return 'Planned date must be on or before deadline';
  }
  return null;
}

DateTime? _scheduleFallbackAnchor(Map<String, dynamic> values) {
  final deadline = values['deadline'];
  if (deadline is DateTime) return deadline;
  final planned = values['planned_at'];
  if (planned is DateTime) return planned;
  return null;
}

String? _validateTaskSchedule(Map<String, dynamic> values) {
  return TaskScheduleFormValues.validate(
    values,
    fallbackAnchor: _scheduleFallbackAnchor(values),
  );
}

String? _validateScheduleModeExclusivity(Map<String, dynamic> values) {
  final mode = TaskScheduleFormValues.modeFrom(values);
  final linked =
      values[TaskScheduleFormKeys.existingScheduleId]?.toString().trim() ?? '';
  final hasInline = mode == TaskScheduleMode.repeating ||
      mode == TaskScheduleMode.oneOff;
  if (mode == TaskScheduleMode.link && linked.isEmpty) {
    return 'Select an existing schedule';
  }
  if (hasInline && linked.isNotEmpty) {
    return 'Use either a linked schedule or inline schedule fields, not both';
  }
  return null;
}

Widget _wizardPage(Widget child) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    ),
  );
}

/// [AnvilFormConfig] for creating or editing a task via [TaskRecordSubmitHandler].
AnvilFormConfig buildTaskFormConfig(
  RecordBloc recordBloc, {
  required ApiClientService apiClient,
  RecordId? recordId,
  Map<String, dynamic> createOverrides = const {},
}) {
  final isEdit = recordId != null;
  return AnvilFormConfig(
    formKey: isEdit ? 'edit_task' : 'create_task',
    steps: const ['main', 'schedule', 'subtasks'],
    pages: {
      'main': AnvilFormPage(
        builder: (context, state) => _wizardPage(const TaskFormMainFields()),
      ),
      'schedule': AnvilFormPage(
        builder: (context, state) => _wizardPage(
          TaskScheduleFields(
            fieldDecoration: CompanionFormStyles.fieldDecoration(context),
            apiClient: apiClient,
          ),
        ),
      ),
      'subtasks': AnvilFormPage(
        builder: (context, state) => _wizardPage(
          const TransparentFormPanel(
            child: TaskSubtasksField(),
          ),
        ),
      ),
    },
    initialValues: isEdit
        ? const {}
        : {
            'status': 'pending',
            'priority': 'medium',
            ...TaskScheduleFormValues.defaultCreateValues(),
            TaskSubtaskFormKeys.subtasks:
                TaskSubtaskFormValues.emptyFormEntries(),
            ...createOverrides,
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
        fieldKey: 'project_id',
        validate: _validateTaskParentExclusivity,
      ),
      AnvilFormValidationRule(
        fieldKey: 'goal_id',
        validate: _validateTaskParentExclusivity,
      ),
      AnvilFormValidationRule(
        fieldKey: 'planned_at',
        validate: _validatePlannedBeforeDeadline,
      ),
      AnvilFormValidationRule(
        fieldKey: 'deadline',
        validate: (values) {
          final plannedError = _validatePlannedBeforeDeadline(values);
          if (plannedError != null) return plannedError;
          final mode = TaskScheduleFormValues.modeFrom(values);
          if (mode == TaskScheduleMode.oneOff &&
              values['deadline'] is! DateTime) {
            return 'Deadline is required for one-off scheduled tasks';
          }
          return null;
        },
      ),
      AnvilFormValidationRule(
        fieldKey: TaskScheduleFormKeys.scheduleMode,
        validate: (values) {
          final exclusivity = _validateScheduleModeExclusivity(values);
          if (exclusivity != null) return exclusivity;
          return _validateTaskSchedule(values);
        },
      ),
      AnvilFormValidationRule(
        fieldKey: TaskScheduleFormKeys.repeatType,
        validate: _validateTaskSchedule,
      ),
    ],
    submitHandler: TaskRecordSubmitHandler(
      recordBloc: recordBloc,
      apiClient: apiClient,
      recordId: recordId,
    ),
  );
}
