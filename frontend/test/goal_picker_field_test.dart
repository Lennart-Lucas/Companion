import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/goals/forms/goal_picker_field.dart';
import 'support/companion_test_helpers.dart';

class _NoOpHandler extends FormSubmitHandler {
  @override
  bool get canHydrate => false;

  @override
  Future<Map<String, dynamic>> hydrate() async => {};

  @override
  Future<FormSubmitResult> submit(Map<String, dynamic> values) async =>
      const FormSubmitResult.success();
}

AnvilFormConfig _formConfig({
  Map<String, dynamic> initialValues = const {},
}) {
  return AnvilFormConfig(
    formKey: 'test',
    steps: ['main'],
    pages: {
      'main': AnvilFormPage(
        builder: (ctx, state) => const SizedBox(),
      ),
    },
    initialValues: initialValues,
    submitHandler: _NoOpHandler(),
  );
}

class _TestHarness {
  late MockHttpClientService mockHttp;
  late RecordBloc recordBloc;
  late AnvilFormBloc formBloc;

  _TestHarness({Map<String, dynamic> initialFormValues = const {}}) {
    mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local',
      delay: Duration.zero,
      initialData: {
        'trackers': [
          {
            'id': '5',
            'name': 'Go to the gym',
            'check_in_type': 'task',
          },
        ],
        'goals': [
          {'id': '5', 'name': 'Loose weight'},
          {'id': '10', 'name': 'Ship MVP'},
        ],
      },
    );

    final api = ApiClientService(mockHttp);
    final repo = HttpRecordRepositoryService(api);
    final coordinator =
        RecordCoordinatorService(buildCompanionRecordRegistry(), repo);
    recordBloc = RecordBloc(coordinator);
    formBloc = AnvilFormBloc(
      config: _formConfig(initialValues: initialFormValues),
    );
  }

  Widget buildWidget(Widget field) {
    return MaterialApp(
      theme: theHubTheme,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AnvilFormBloc>.value(value: formBloc),
          BlocProvider<RecordBloc>.value(value: recordBloc),
        ],
        child: Scaffold(body: field),
      ),
    );
  }

  Future<void> dispose() async {
    await formBloc.close();
    await recordBloc.close();
    mockHttp.close();
  }
}

void main() {
  group('GoalPickerField', () {
    late _TestHarness harness;

    tearDown(() => harness.dispose());

    testWidgets('shows goal name when goal_id collides with tracker id in cache',
        (tester) async {
      harness = _TestHarness(initialFormValues: {'goal_id': '5'});

      harness.recordBloc.add(
        const GetRecordRequested(recordType: 'trackers', recordId: '5'),
      );
      await tester.pumpWidget(
        harness.buildWidget(const GoalPickerField(label: 'Goal')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await pumpUntilFound(tester, find.text('Loose weight'));

      expect(find.text('Loose weight'), findsOneWidget);
      expect(find.text('Go to the gym'), findsNothing);
    });

    testWidgets('selecting a goal sets goal_id', (tester) async {
      harness = _TestHarness();

      await tester.pumpWidget(
        harness.buildWidget(const GoalPickerField(label: 'Goal')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('None'));
      await pumpUntilFound(tester, find.text('Ship MVP'));

      await tester.tap(find.text('Ship MVP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.formBloc.state.values['goal_id'], '10');
      expect(find.text('Ship MVP'), findsOneWidget);
    });
  });
}
