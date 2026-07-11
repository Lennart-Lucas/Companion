import 'package:flutter/material.dart';
import 'package:frontend/core/scheduling/schedule_form_fields.dart';

/// Repeat / schedule controls for the goal form (always required).
class GoalScheduleFields extends StatelessWidget {
  const GoalScheduleFields({super.key, required this.fieldDecoration});

  final InputDecoration fieldDecoration;

  @override
  Widget build(BuildContext context) {
    return ScheduleFormFields(
      config: ScheduleFormConfigs.goal,
      fieldDecoration: fieldDecoration,
    );
  }
}
