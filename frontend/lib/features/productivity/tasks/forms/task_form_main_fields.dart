import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/tasks/forms/task_field_option_tile.dart';
import 'package:frontend/features/productivity/tasks/forms/task_parent_picker_field.dart';
import 'package:frontend/features/productivity/tasks/forms/task_planned_deadline_fields.dart';
import 'package:frontend/core/scheduling/schedule_form_values.dart';
import 'package:frontend/features/productivity/shared/widgets/transparent_form_panel.dart';

/// Main wizard step: details, dates, and parent pickers.
class TaskFormMainFields extends StatelessWidget {
  const TaskFormMainFields({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fieldDecoration = CompanionFormStyles.fieldDecoration(context);
    const fieldSpacing = CompanionFormStyles.fieldSpacing;
    const headerTop = CompanionFormStyles.sectionHeaderMarginTop;
    const headerBottom = CompanionFormStyles.sectionHeaderMarginBottom;

    final scheduleMode = context.select<AnvilFormBloc, String>(
      (bloc) => TaskScheduleFormValues.modeFrom(bloc.state.values),
    );
    final dateFieldsEnabled = TaskScheduleMode.usesTaskDates(scheduleMode);
    final statusFieldEnabled = dateFieldsEnabled;
    final dateDecoration = taskDateFieldDecoration(
      context,
      fieldDecoration,
      enabled: dateFieldsEnabled,
    );
    final statusDecoration = taskDateFieldDecoration(
      context,
      fieldDecoration,
      enabled: statusFieldEnabled,
    );
    final useDateTimeDeadline = scheduleMode == TaskScheduleMode.oneOff;

    return TaskRepeatPlannedDeadlineSync(
      child: TransparentFormPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnvilFormSection(
              title: 'Details',
              subtitle: 'Name and notes for this task',
              padding: EdgeInsets.zero,
              spacing: fieldSpacing,
              headerMarginTop: 16,
              headerMarginBottom: headerBottom,
              children: [
                AnvilTextField(
                  fieldKey: 'name',
                  label: 'Name',
                  isRequired: true,
                  placeholder: 'What needs to be done?',
                  decoration: fieldDecoration,
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
              title: 'When & status',
              subtitle: 'Planned date, deadline, priority, and workflow state',
              padding: EdgeInsets.zero,
              showDivider: true,
              spacing: fieldSpacing,
              headerMarginTop: headerTop,
              headerMarginBottom: headerBottom,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth <
                        CompanionFormStyles.formFieldRowNarrowBreakpoint;

                    final plannedField = wrapDisabledTaskDateField(
                      scheduleMode: scheduleMode,
                      child: AnvilDateField(
                        fieldKey: taskPlannedAtFieldKey,
                        label: 'Planned',
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        enabled: dateFieldsEnabled,
                        decoration: dateDecoration,
                      ),
                    );

                    final deadlineField = wrapDisabledTaskDateField(
                      scheduleMode: scheduleMode,
                      child: useDateTimeDeadline
                          ? AnvilDateTimeField(
                              fieldKey: taskDeadlineFieldKey,
                              label: 'Deadline',
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              use24HourFormat: true,
                              enabled: dateFieldsEnabled,
                              decoration: dateDecoration,
                            )
                          : AnvilDateField(
                              fieldKey: taskDeadlineFieldKey,
                              label: 'Deadline',
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              enabled: dateFieldsEnabled,
                              decoration: dateDecoration,
                            ),
                    );

                    final priorityField = AnvilDropdownField<String>(
                      fieldKey: 'priority',
                      label: 'Priority',
                      isRequired: true,
                      options: taskPriorityOptions(),
                      decoration: fieldDecoration,
                      itemBuilder: (opt) => taskPriorityOptionTile(
                        opt,
                        taskPriorityColor(opt.value, scheme),
                      ),
                    );

                    final statusField = wrapDisabledTaskDateField(
                      scheduleMode: scheduleMode,
                      child: AnvilDropdownField<String>(
                        fieldKey: taskStatusFieldKey,
                        label: 'Status',
                        isRequired: true,
                        enabled: statusFieldEnabled,
                        options: taskStatusOptions(),
                        decoration: statusDecoration,
                        itemBuilder: (opt) =>
                            taskStatusOptionTile(opt, scheme),
                      ),
                    );

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          plannedField,
                          const SizedBox(height: fieldSpacing),
                          deadlineField,
                          const SizedBox(height: fieldSpacing),
                          priorityField,
                          const SizedBox(height: fieldSpacing),
                          statusField,
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnvilFormRow(children: [plannedField, deadlineField]),
                        const SizedBox(height: fieldSpacing),
                        AnvilFormRow(children: [priorityField, statusField]),
                      ],
                    );
                  },
                ),
              ],
            ),
            AnvilFormSection(
              title: 'Parent',
              subtitle: 'Link to a project or goal (optional)',
              padding: EdgeInsets.zero,
              showDivider: true,
              spacing: fieldSpacing,
              headerMarginTop: headerTop,
              headerMarginBottom: headerBottom,
              children: [
                TaskParentPickerField(
                  label: null,
                  decoration: fieldDecoration,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Back-compat alias for tests that pump the main fields only.
typedef TaskFormFields = TaskFormMainFields;
