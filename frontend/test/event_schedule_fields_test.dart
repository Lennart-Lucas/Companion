import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/forms/event_schedule_fields.dart';
import 'package:frontend/features/productivity/models/task_schedule.dart';

class _NoOpHandler extends FormSubmitHandler {
  @override
  bool get canHydrate => false;

  @override
  Future<Map<String, dynamic>> hydrate() async => {};

  @override
  Future<FormSubmitResult> submit(Map<String, dynamic> values) async =>
      const FormSubmitResult.success();
}

class _FakeApi {
  _FakeApi() : client = ApiClientService(
          MockHttpClientService(baseUrl: 'http://mock.local/api/v1'),
        );

  final ApiClientService client;
}

void main() {
  testWidgets('shows repeat fields when mode is repeating', (tester) async {
    final formBloc = AnvilFormBloc(
      config: AnvilFormConfig(
        formKey: 'test',
        steps: ['main'],
        pages: {
          'main': AnvilFormPage(
            builder: (_, __) => const SizedBox(),
          ),
        },
        initialValues: {
          ...TaskScheduleFormValues.defaultCreateValues(),
          TaskScheduleFormKeys.scheduleMode: TaskScheduleMode.repeating,
          TaskScheduleFormKeys.repeatType: TaskRepeatType.everyNWeeks,
          TaskScheduleFormKeys.startDate: DateTime(2026, 8, 1),
        },
        submitHandler: _NoOpHandler(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AnvilFormBloc>.value(
          value: formBloc,
          child: Scaffold(
            body: EventScheduleFields(
              fieldDecoration: const InputDecoration(),
              apiClient: _FakeApi().client,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Schedule'), findsOneWidget);
    expect(find.textContaining('Repeat mode'), findsOneWidget);
    expect(find.textContaining('time window'), findsOneWidget);

    addTearDown(formBloc.close);
  });

  testWidgets('hides repeat fields when mode is off', (tester) async {
    final formBloc = AnvilFormBloc(
      config: AnvilFormConfig(
        formKey: 'test',
        steps: ['main'],
        pages: {
          'main': AnvilFormPage(
            builder: (_, __) => const SizedBox(),
          ),
        },
        initialValues: TaskScheduleFormValues.defaultCreateValues(),
        submitHandler: _NoOpHandler(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AnvilFormBloc>.value(
          value: formBloc,
          child: Scaffold(
            body: EventScheduleFields(
              fieldDecoration: const InputDecoration(),
              apiClient: _FakeApi().client,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Schedule mode'), findsOneWidget);
    expect(find.text('Repeat mode'), findsNothing);

    addTearDown(formBloc.close);
  });
}
