import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/events/forms/event_form_fields.dart';
import 'package:frontend/features/productivity/events/forms/event_record_submit_handler.dart';
import 'package:frontend/features/productivity/events/forms/event_schedule_fields.dart';
import 'package:frontend/features/productivity/events/models/event.dart';

import 'package:frontend/core/scheduling/schedule_form_values.dart';

DateTime _defaultStartAt() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, now.hour, now.minute);
}

String? _validateEndAt(Map<String, dynamic> values) {
  final start = values[eventStartAtFieldKey];
  final end = values[eventEndAtFieldKey];
  if (start is! DateTime || end is! DateTime) {
    return null;
  }
  if (!end.isAfter(start)) {
    return 'End must be after the start';
  }
  return null;
}

String? _validateScheduleModeExclusivity(Map<String, dynamic> values) {
  final mode = TaskScheduleFormValues.modeFrom(values);
  final linked =
      values[TaskScheduleFormKeys.existingScheduleId]?.toString().trim() ?? '';
  final hasInline = mode == TaskScheduleMode.repeating;
  if (mode == TaskScheduleMode.link && linked.isEmpty) {
    return 'Select an existing schedule';
  }
  if (hasInline && linked.isNotEmpty) {
    return 'Use either a linked schedule or inline schedule fields, not both';
  }
  return null;
}

String? _validateEventSchedule(Map<String, dynamic> values) {
  final mode = TaskScheduleFormValues.modeFrom(values);
  if (mode == TaskScheduleMode.oneOff) {
    return null;
  }
  return TaskScheduleFormValues.validate(
    values,
    fallbackAnchor: values[eventStartAtFieldKey] as DateTime?,
  );
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

/// [AnvilFormConfig] for creating or editing an event via [RecordBloc].
AnvilFormConfig buildEventFormConfig(
  RecordBloc recordBloc, {
  ApiClientService? apiClient,
  RecordId? recordId,
  Event? preloadedEvent,
}) {
  final isEdit = recordId != null;
  final resolvedApi = apiClient ?? CompanionAnvilApp.instance.apiClient;

  return AnvilFormConfig(
    formKey: isEdit ? 'edit_event' : 'create_event',
    steps: const ['main', 'schedule'],
    pages: {
      'main': AnvilFormPage(
        builder: (context, state) => _wizardPage(const EventFormFields()),
      ),
      'schedule': AnvilFormPage(
        builder: (context, state) => _wizardPage(
          EventScheduleFields(
            fieldDecoration: CompanionFormStyles.fieldDecoration(context),
            apiClient: resolvedApi,
          ),
        ),
      ),
    },
    initialValues: isEdit
        ? const {}
        : {
            eventStartAtFieldKey: _defaultStartAt(),
            ...TaskScheduleFormValues.defaultCreateValues(),
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
        fieldKey: eventStartAtFieldKey,
        validate: (values) {
          final start = values[eventStartAtFieldKey];
          if (start is! DateTime) return 'Start date and time are required';
          return null;
        },
      ),
      AnvilFormValidationRule(
        fieldKey: eventEndAtFieldKey,
        validate: _validateEndAt,
      ),
      AnvilFormValidationRule(
        fieldKey: TaskScheduleFormKeys.scheduleMode,
        validate: (values) {
          final exclusivity = _validateScheduleModeExclusivity(values);
          if (exclusivity != null) return exclusivity;
          return _validateEventSchedule(values);
        },
      ),
      AnvilFormValidationRule(
        fieldKey: TaskScheduleFormKeys.repeatType,
        validate: _validateEventSchedule,
      ),
    ],
    submitHandler: EventRecordSubmitHandler(
      recordBloc: recordBloc,
      apiClient: resolvedApi,
      recordId: recordId,
      preloadedEvent: preloadedEvent,
    ),
  );
}
