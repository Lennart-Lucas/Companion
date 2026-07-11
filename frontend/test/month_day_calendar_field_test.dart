import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/scheduling/month_day_calendar_field.dart';
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
  testWidgets('renders month days in a calendar grid', (tester) async {
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
          TaskScheduleFormKeys.monthDays: const [1, 15],
        },
        submitHandler: _NoOpHandler(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AnvilFormBloc>.value(
          value: formBloc,
          child: const Scaffold(
            body: MonthDayCalendarField(
              fieldKey: TaskScheduleFormKeys.monthDays,
              label: 'Days of month',
              isRequired: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Days of month *'), findsOneWidget);
    expect(find.text('Mon'), findsNothing);
    expect(find.text('31'), findsOneWidget);

    await tester.tap(find.text('10'));
    await tester.pump();

    final selected =
        formBloc.state.values[TaskScheduleFormKeys.monthDays] as List<int>;
    expect(selected, [1, 10, 15]);

    addTearDown(formBloc.close);
  });
}
