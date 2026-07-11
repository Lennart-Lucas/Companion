import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/shared/widgets/transparent_form_panel.dart';

const eventStartAtFieldKey = 'start_at';
const eventEndAtFieldKey = 'end_at';

/// Fields for the create/edit event [AnvilForm] main step.
class EventFormFields extends StatelessWidget {
  const EventFormFields({super.key});

  static const _narrowBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
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
                    compactSquare: true,
                    decoration: fieldDecoration,
                  ),
                  const SizedBox(width: fieldSpacing),
                  Expanded(
                    child: AnvilTextField(
                      fieldKey: 'name',
                      label: 'Name',
                      isRequired: true,
                      placeholder: 'What is this event?',
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
            title: 'When',
            subtitle: 'Start and optional end date & time',
            padding: EdgeInsets.zero,
            showDivider: true,
            spacing: fieldSpacing,
            headerMarginTop: headerTop,
            headerMarginBottom: headerBottom,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < _narrowBreakpoint;
                  final dateFields = [
                    AnvilDateTimeField(
                      fieldKey: eventStartAtFieldKey,
                      label: 'Start',
                      isRequired: true,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      use24HourFormat: true,
                      decoration: fieldDecoration,
                    ),
                    AnvilDateTimeField(
                      fieldKey: eventEndAtFieldKey,
                      label: 'End',
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      use24HourFormat: true,
                      decoration: fieldDecoration,
                    ),
                  ];

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < dateFields.length; i++) ...[
                          if (i > 0) const SizedBox(height: fieldSpacing),
                          dateFields[i],
                        ],
                      ],
                    );
                  }

                  return AnvilFormRow(children: dateFields);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
