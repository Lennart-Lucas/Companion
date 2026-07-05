import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/project_form_fields.dart';
import 'package:frontend/features/productivity/forms/project_record_submit_handler.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

/// [AnvilFormConfig] for creating or editing a project via [RecordBloc].
AnvilFormConfig buildProjectFormConfig(
  RecordBloc recordBloc, {
  RecordId? recordId,
  Project? preloadedProject,
}) {
  final isEdit = recordId != null;
  return AnvilFormConfig(
    formKey: isEdit ? 'edit_project' : 'create_project',
    steps: const ['main'],
    pages: {
      'main': AnvilFormPage(
        builder: (context, state) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const ProjectFormFields(),
            ),
          ),
        ),
      ),
    },
    initialValues: isEdit
        ? const {}
        : const {
            'status': 'planning',
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
    ],
    submitHandler: isEdit
        ? ProjectRecordSubmitHandler(
            recordBloc: recordBloc,
            recordId: recordId,
            preloadedProject: preloadedProject,
          )
        : RecordSubmitHandler(
            recordBloc: recordBloc,
            recordType: 'projects',
            toRecord: (values) => Project.fromFormValues(values),
            fromRecord: (record) => (record as Project).toFormValues(),
          ),
  );
}
