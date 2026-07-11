import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/scheduling/schedule_form_fields.dart'
    show
        ScheduleFormConfigs,
        ScheduleFormFields,
        applyEventScheduleModeSideEffects;

export 'package:frontend/core/scheduling/schedule_form_fields.dart'
    show applyEventScheduleModeSideEffects;

/// Schedule step for the event form wizard.
class EventScheduleFields extends StatelessWidget {
  const EventScheduleFields({
    super.key,
    required this.fieldDecoration,
    required this.apiClient,
  });

  final InputDecoration fieldDecoration;
  final ApiClientService apiClient;

  @override
  Widget build(BuildContext context) {
    return ScheduleFormFields(
      config: ScheduleFormConfigs.event,
      fieldDecoration: fieldDecoration,
      apiClient: apiClient,
    );
  }
}
