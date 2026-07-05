import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/forms/goal_picker_field.dart';
import 'package:frontend/features/productivity/forms/task_schedule_fields.dart';
import 'package:frontend/features/productivity/forms/tracker_duration_target_field.dart';
import 'package:frontend/features/productivity/forms/tracker_field_option_tile.dart';
import 'package:frontend/features/productivity/forms/tracker_schedule_fields.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/widgets/transparent_form_panel.dart';

/// Fields for the create/edit tracker [AnvilForm] main step.
class TrackerFormFields extends StatelessWidget {
  const TrackerFormFields({super.key});

  static const _narrowBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fieldDecoration = CompanionFormStyles.fieldDecoration(context);
    const fieldSpacing = CompanionFormStyles.fieldSpacing;
    const headerTop = CompanionFormStyles.sectionHeaderMarginTop;
    const headerBottom = CompanionFormStyles.sectionHeaderMarginBottom;

    return TaskScheduleTimezoneInitializer(
      child: TransparentFormPanel(
        opacity: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnvilFormSection(
              title: 'Details',
              subtitle: 'Icon, name, and notes',
              padding: EdgeInsets.zero,
              spacing: fieldSpacing,
              headerMarginTop: 16,
              headerMarginBottom: headerBottom,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnvilIconColorPickerField(
                      iconFieldKey: 'icon',
                      colorFieldKey: 'color',
                      compactSquare: true,
                      decoration: fieldDecoration,
                    ),
                    const SizedBox(width: fieldSpacing),
                    Expanded(
                      child: AnvilTextField(
                        fieldKey: 'name',
                        label: 'Name',
                        isRequired: true,
                        placeholder: 'What are you tracking?',
                        decoration: fieldDecoration,
                      ),
                    ),
                  ],
                ),
                AnvilTextField(
                  fieldKey: 'description',
                  label: 'Description',
                  placeholder: 'Optional notes...',
                  minLines: 3,
                  maxLines: 5,
                  decoration: fieldDecoration,
                ),
              ],
            ),
            AnvilFormSection(
              title: 'Goal',
              subtitle: 'Link this tracker to a goal',
              padding: EdgeInsets.zero,
              showDivider: true,
              spacing: fieldSpacing,
              headerMarginTop: headerTop,
              headerMarginBottom: headerBottom,
              children: [
                GoalPickerField(
                  label: null,
                  decoration: fieldDecoration,
                ),
              ],
            ),
            AnvilFormSection(
              title: 'Tracking',
              subtitle: 'Check-in type and habit',
              padding: EdgeInsets.zero,
              showDivider: true,
              spacing: fieldSpacing,
              headerMarginTop: headerTop,
              headerMarginBottom: headerBottom,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < _narrowBreakpoint;
                    final trackingFields = [
                      AnvilDropdownField<String>(
                        fieldKey: 'check_in_type',
                        label: 'Check-in type',
                        isRequired: true,
                        options: trackerCheckInTypeOptions(),
                        decoration: fieldDecoration,
                        itemBuilder: (opt) =>
                            trackerCheckInTypeOptionTile(opt, scheme),
                      ),
                      AnvilDropdownField<String>(
                        fieldKey: 'habit_direction',
                        label: 'Habit direction',
                        isRequired: true,
                        options: trackerHabitDirectionOptions(),
                        decoration: fieldDecoration,
                        itemBuilder: (opt) =>
                            trackerHabitDirectionOptionTile(opt, scheme),
                      ),
                    ];

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < trackingFields.length; i++) ...[
                            if (i > 0) const SizedBox(height: fieldSpacing),
                            trackingFields[i],
                          ],
                        ],
                      );
                    }

                    return AnvilFormRow(children: trackingFields);
                  },
                ),
                _TrackerTargetFields(
                  decoration: fieldDecoration,
                  narrowBreakpoint: _narrowBreakpoint,
                ),
              ],
            ),
            TrackerScheduleFields(fieldDecoration: fieldDecoration),
          ],
        ),
      ),
    );
  }
}

class _TrackerTargetFields extends StatelessWidget {
  const _TrackerTargetFields({
    required this.decoration,
    required this.narrowBreakpoint,
  });

  final InputDecoration decoration;
  final double narrowBreakpoint;

  @override
  Widget build(BuildContext context) {
    final checkInType = context.select<AnvilFormBloc, String>(
      (bloc) =>
          bloc.state.values['check_in_type']?.toString() ??
          TrackerCheckInType.task,
    );

    if (checkInType == TrackerCheckInType.task) {
      return const SizedBox.shrink();
    }

    if (checkInType == TrackerCheckInType.count) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < narrowBreakpoint;
          final countFields = [
            AnvilNumberField(
              fieldKey: 'target',
              label: 'Target',
              isRequired: true,
              min: 0,
              decoration: decoration,
            ),
            AnvilTextField(
              fieldKey: 'unit',
              label: 'Unit',
              isRequired: true,
              placeholder: 'e.g. glasses',
              decoration: decoration,
            ),
          ];

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                countFields[0],
                const SizedBox(height: CompanionFormStyles.fieldSpacing),
                countFields[1],
              ],
            );
          }

          return AnvilFormRow(children: countFields);
        },
      );
    }

    return TrackerDurationTargetField(
      fieldKey: 'target',
      isRequired: true,
      decoration: decoration,
    );
  }
}
