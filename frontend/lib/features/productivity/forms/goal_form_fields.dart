import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/forms/goal_field_option_tile.dart';
import 'package:frontend/features/productivity/forms/goal_schedule_fields.dart';
import 'package:frontend/features/productivity/forms/task_schedule_fields.dart';
import 'package:frontend/features/productivity/widgets/transparent_form_panel.dart';

/// Fields for the create/edit goal [AnvilForm] main step.
class GoalFormFields extends StatelessWidget {
  const GoalFormFields({super.key});

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
                        placeholder: 'What do you want to achieve?',
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
              title: 'Target',
              subtitle: 'Type and target',
              padding: EdgeInsets.zero,
              showDivider: true,
              spacing: fieldSpacing,
              headerMarginTop: headerTop,
              headerMarginBottom: headerBottom,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < _narrowBreakpoint;
                    final typeFields = [
                      AnvilDropdownField<String>(
                        fieldKey: 'goal_type',
                        label: 'Goal type',
                        isRequired: true,
                        options: goalTypeOptions(),
                        decoration: fieldDecoration,
                        itemBuilder: (opt) => goalTypeOptionTile(opt, scheme),
                      ),
                      AnvilDropdownField<String>(
                        fieldKey: 'direction',
                        label: 'Direction',
                        isRequired: true,
                        options: goalDirectionOptions(),
                        decoration: fieldDecoration,
                        itemBuilder: (opt) =>
                            goalDirectionOptionTile(opt, scheme),
                      ),
                    ];

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < typeFields.length; i++) ...[
                            if (i > 0) const SizedBox(height: fieldSpacing),
                            typeFields[i],
                          ],
                        ],
                      );
                    }

                    return AnvilFormRow(children: typeFields);
                  },
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < _narrowBreakpoint;
                    final targetFields = [
                      AnvilNumberField(
                        fieldKey: 'target',
                        label: 'Target',
                        isRequired: true,
                        min: 0,
                        decoration: fieldDecoration,
                      ),
                      AnvilTextField(
                        fieldKey: 'unit',
                        label: 'Unit',
                        isRequired: true,
                        placeholder: 'e.g. books',
                        decoration: fieldDecoration,
                      ),
                    ];

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < targetFields.length; i++) ...[
                            if (i > 0) const SizedBox(height: fieldSpacing),
                            targetFields[i],
                          ],
                        ],
                      );
                    }

                    return AnvilFormRow(children: targetFields);
                  },
                ),
              ],
            ),
            GoalScheduleFields(fieldDecoration: fieldDecoration),
          ],
        ),
      ),
    );
  }
}
