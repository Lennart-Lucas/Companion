export 'package:frontend/core/scheduling/schedule_form_fields.dart'
    show
        ScheduleDateListField,
        ScheduleTimezoneInitializer,
        TaskScheduleTimezoneInitializer;

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/scheduling/schedule_form_fields.dart';

/// Schedule step for the task form wizard.
class TaskScheduleFields extends StatelessWidget {
  const TaskScheduleFields({
    super.key,
    required this.fieldDecoration,
    required this.apiClient,
  });

  final InputDecoration fieldDecoration;
  final ApiClientService apiClient;

  @override
  Widget build(BuildContext context) {
    return ScheduleFormFields(
      config: ScheduleFormConfigs.task,
      fieldDecoration: fieldDecoration,
      apiClient: apiClient,
    );
  }
}
