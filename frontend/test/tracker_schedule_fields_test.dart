import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/trackers/forms/tracker_schedule_fields.dart';
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

void main() {
  testWidgets('shows recurrence fields for new tracker', (tester) async {
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
          TaskScheduleFormKeys.repeatEnabled: true,
        },
        submitHandler: _NoOpHandler(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AnvilFormBloc>.value(
          value: formBloc,
          child: Scaffold(
            body: TrackerScheduleFields(
              fieldDecoration: const InputDecoration(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Recurrence for this tracker'), findsOneWidget);
    expect(find.textContaining('Start date'), findsOneWidget);
    expect(find.textContaining('End date'), findsOneWidget);
    expect(find.textContaining('Repeat mode'), findsOneWidget);
    expect(find.textContaining('Every 1 day'), findsOneWidget);

    addTearDown(formBloc.close);
  });
}
