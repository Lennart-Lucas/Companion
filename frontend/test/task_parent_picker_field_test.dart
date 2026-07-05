import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/forms/task_parent_picker_field.dart';

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
        'projects': [
          {'id': '1', 'name': 'Alpha Project', 'status': 'planning'},
          {'id': '2', 'name': 'Beta Project', 'status': 'active'},
        ],
        'goals': [
          {'id': '10', 'name': 'Ship MVP'},
          {'id': '11', 'name': 'Learn Flutter'},
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
  group('TaskParentPickerField', () {
    late _TestHarness harness;

    tearDown(() => harness.dispose());

    testWidgets('shows placeholder when no parent is selected', (tester) async {
      harness = _TestHarness();
      await tester.pumpWidget(
        harness.buildWidget(const TaskParentPickerField()),
      );
      await tester.pumpAndSettle();

      expect(find.text('None'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('selecting a project sets project_id and clears goal_id',
        (tester) async {
      harness = _TestHarness();
      await tester.pumpWidget(
        harness.buildWidget(const TaskParentPickerField()),
      );

      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();

      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);

      await tester.tap(find.text('Alpha Project'));
      await tester.pumpAndSettle();

      expect(harness.formBloc.state.values['project_id'], '1');
      expect(harness.formBloc.state.values['goal_id'], isNull);
      expect(find.text('Alpha Project'), findsOneWidget);
      expect(find.text('Project'), findsWidgets);
    });

    testWidgets('selecting a goal sets goal_id and clears project_id',
        (tester) async {
      harness = _TestHarness(initialFormValues: {'project_id': '1'});
      harness.recordBloc.add(
        const QueryRecordsRequested(RecordQuery(recordType: 'projects')),
      );

      await tester.pumpWidget(
        harness.buildWidget(const TaskParentPickerField()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha Project'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ship MVP'));
      await tester.pumpAndSettle();

      expect(harness.formBloc.state.values['goal_id'], '10');
      expect(harness.formBloc.state.values['project_id'], isNull);
      expect(find.text('Ship MVP'), findsOneWidget);
    });

    testWidgets('clear button removes both parent ids', (tester) async {
      harness = _TestHarness(initialFormValues: {'project_id': '1'});
      harness.recordBloc.add(
        const QueryRecordsRequested(RecordQuery(recordType: 'projects')),
      );

      await tester.pumpWidget(
        harness.buildWidget(const TaskParentPickerField()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(harness.formBloc.state.values['project_id'], isNull);
      expect(harness.formBloc.state.values['goal_id'], isNull);
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('search filters projects and goals in overlay', (tester) async {
      harness = _TestHarness();
      await tester.pumpWidget(
        harness.buildWidget(const TaskParentPickerField()),
      );

      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ship');
      await tester.pumpAndSettle();

      expect(find.text('Ship MVP'), findsOneWidget);
      expect(find.text('Alpha Project'), findsNothing);
      expect(find.text('Learn Flutter'), findsNothing);
    });
  });
}
