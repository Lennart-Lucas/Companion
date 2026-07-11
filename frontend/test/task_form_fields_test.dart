import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/tasks/forms/task_form_fields.dart';
import 'package:frontend/features/productivity/tasks/forms/task_planned_deadline_fields.dart';
import 'package:frontend/features/productivity/models/task_schedule.dart';

AnvilDateField _dateField(WidgetTester tester, String fieldKey) {
  return tester.widget<AnvilDateField>(
    find.byWidgetPredicate(
      (widget) =>
          widget is AnvilDateField && widget.fieldKey == fieldKey,
    ),
  );
}

AnvilDropdownField<String> _dropdownField(WidgetTester tester, String fieldKey) {
  return tester.widget<AnvilDropdownField<String>>(
    find.byWidgetPredicate(
      (widget) =>
          widget is AnvilDropdownField<String> &&
          widget.fieldKey == fieldKey,
    ),
  );
}

Future<(AnvilApp, AnvilFormBloc)> _pumpTaskFormFields(
  WidgetTester tester, {
  required Map<String, dynamic> initialValues,
}) async {
  setupCompanionIcons();
  final app = AnvilApp(
    baseUrl: 'http://mock.local/api/v1',
    tokenStorage: InMemoryTokenStorage(),
    recordRegistry: buildCompanionRecordRegistry(),
    httpClient: MockHttpClientService(baseUrl: 'http://mock.local/api/v1'),
  );

  final formBloc = AnvilFormBloc(
    config: AnvilFormConfig(
      formKey: 'test',
      steps: ['main'],
      pages: {
        'main': AnvilFormPage(builder: (_, __) => const SizedBox()),
      },
      initialValues: initialValues,
      submitHandler: _NoOpHandler(),
    ),
  );

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<RecordBloc>.value(value: app.recordBloc),
        BlocProvider<AnvilFormBloc>.value(value: formBloc),
      ],
      child: MaterialApp(
        theme: theHubTheme,
        home: const Scaffold(
          body: SingleChildScrollView(child: TaskFormFields()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  addTearDown(() {
    formBloc.close();
    app.dispose();
  });

  return (app, formBloc);
}

class _NoOpHandler extends FormSubmitHandler {
  @override
  bool get canHydrate => false;

  @override
  Future<Map<String, dynamic>> hydrate() async => {};

  @override
  Future<FormSubmitResult> submit(Map<String, dynamic> values) async =>
      const FormSubmitResult.success();
}

void main() {
  testWidgets('planned and deadline enabled when repeat is off', (
    WidgetTester tester,
  ) async {
    await _pumpTaskFormFields(
      tester,
      initialValues: TaskScheduleFormValues.defaultCreateValues(),
    );

    expect(_dateField(tester, taskPlannedAtFieldKey).enabled, isTrue);
    expect(_dateField(tester, taskDeadlineFieldKey).enabled, isTrue);
    expect(_dropdownField(tester, taskStatusFieldKey).enabled, isTrue);
  });

  testWidgets('status disabled and reset to pending when repeating', (
    WidgetTester tester,
  ) async {
    final (_, formBloc) = await _pumpTaskFormFields(
      tester,
      initialValues: {
        ...TaskScheduleFormValues.defaultCreateValues(),
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
        taskStatusFieldKey: 'in_progress',
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_dropdownField(tester, taskStatusFieldKey).enabled, isFalse);
    expect(formBloc.state.values[taskStatusFieldKey], 'pending');
  });

  testWidgets('planned and deadline disabled when repeating', (
    WidgetTester tester,
  ) async {
    final (_, formBloc) = await _pumpTaskFormFields(
      tester,
      initialValues: {
        ...TaskScheduleFormValues.defaultCreateValues(),
        TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
        taskPlannedAtFieldKey: DateTime(2026, 6, 1),
        taskDeadlineFieldKey: DateTime(2026, 6, 30),
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_dateField(tester, taskPlannedAtFieldKey).enabled, isFalse);
    expect(_dateField(tester, taskDeadlineFieldKey).enabled, isFalse);
    expect(formBloc.state.values[taskPlannedAtFieldKey], isNull);
    expect(formBloc.state.values[taskDeadlineFieldKey], isNull);

    expect(find.byType(Opacity), findsWidgets);
  });

  testWidgets('switching to repeating clears planned and deadline', (
    WidgetTester tester,
  ) async {
    final (_, formBloc) = await _pumpTaskFormFields(
      tester,
      initialValues: {
        ...TaskScheduleFormValues.defaultCreateValues(),
        taskPlannedAtFieldKey: DateTime(2026, 6, 1),
        taskDeadlineFieldKey: DateTime(2026, 6, 30),
        taskStatusFieldKey: 'completed',
      },
    );

    formBloc.add(
      AnvilFormFieldUpdated(
        TaskScheduleFormKeys.scheduleMode,
        TaskScheduleMode.repeating,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(formBloc.state.values[taskPlannedAtFieldKey], isNull);
    expect(formBloc.state.values[taskDeadlineFieldKey], isNull);
    expect(formBloc.state.values[taskStatusFieldKey], 'pending');
    expect(
      formBloc.state.values[TaskScheduleFormKeys.startDate],
      TaskScheduleFormValues.defaultStartDate(),
    );
  });
}
