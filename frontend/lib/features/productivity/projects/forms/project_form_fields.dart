import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/goals/forms/goal_picker_field.dart';
import 'package:frontend/features/productivity/projects/forms/project_field_option_tile.dart';
import 'package:frontend/features/productivity/shared/widgets/transparent_form_panel.dart';

/// Fields for the create/edit project [AnvilForm] main step.
class ProjectFormFields extends StatelessWidget {
  const ProjectFormFields({super.key});

  static const _narrowBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fieldDecoration = CompanionFormStyles.fieldDecoration(context);
    const fieldSpacing = CompanionFormStyles.fieldSpacing;
    const headerTop = CompanionFormStyles.sectionHeaderMarginTop;
    const headerBottom = CompanionFormStyles.sectionHeaderMarginBottom;

    return TransparentFormPanel(
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
                    registry: companionEntityIconRegistry,
                    compactSquare: true,
                    decoration: fieldDecoration,
                  ),
                  const SizedBox(width: fieldSpacing),
                  Expanded(
                    child: AnvilTextField(
                      fieldKey: 'name',
                      label: 'Name',
                      isRequired: true,
                      placeholder: 'What is this project?',
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
            title: 'Schedule & status',
            subtitle: 'Status and key dates',
            padding: EdgeInsets.zero,
            showDivider: true,
            spacing: fieldSpacing,
            headerMarginTop: headerTop,
            headerMarginBottom: headerBottom,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < _narrowBreakpoint;
                  final scheduleStatusFields = [
                    AnvilDropdownField<String>(
                      fieldKey: 'status',
                      label: 'Status',
                      isRequired: true,
                      options: projectStatusOptions(),
                      decoration: fieldDecoration,
                      itemBuilder: (opt) =>
                          projectStatusOptionTile(opt, scheme),
                    ),
                    AnvilDateField(
                      fieldKey: 'start_date',
                      label: 'Start date',
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      decoration: fieldDecoration,
                    ),
                    AnvilDateField(
                      fieldKey: 'deadline',
                      label: 'Deadline',
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      decoration: fieldDecoration,
                    ),
                  ];

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < scheduleStatusFields.length; i++) ...[
                          if (i > 0) const SizedBox(height: fieldSpacing),
                          scheduleStatusFields[i],
                        ],
                      ],
                    );
                  }

                  return AnvilFormRow(children: scheduleStatusFields);
                },
              ),
            ],
          ),
          AnvilFormSection(
            title: 'Goal',
            subtitle: 'Link this project to a goal (optional)',
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
        ],
      ),
    );
  }
}
