import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/scheduling/schedule_form_fields.dart';

/// Repeat / schedule controls for the tracker form (always required).
class TrackerScheduleFields extends StatelessWidget {
  const TrackerScheduleFields({super.key, required this.fieldDecoration});

  final InputDecoration fieldDecoration;

  @override
  Widget build(BuildContext context) {
    return ScheduleFormFields(
      config: ScheduleFormConfigs.tracker,
      fieldDecoration: fieldDecoration,
    );
  }
}
