import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/forms/goal_form_config.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

void main() {
  testWidgets('GoalEditPage shows edit goal form', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    final app = AnvilApp(
      baseUrl: 'http://mock.local/api/v1',
      tokenStorage: InMemoryTokenStorage(),
      recordRegistry: buildCompanionRecordRegistry(),
      httpClient: MockHttpClientService(baseUrl: 'http://mock.local/api/v1'),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: app.authBloc!),
          BlocProvider<RecordBloc>.value(value: app.recordBloc),
        ],
        child: MaterialApp(
          theme: theHubTheme,
          home: Scaffold(
            appBar: AppBar(title: const Text('Edit goal')),
            body: AnvilForm(
              config: buildGoalFormConfig(
                app.recordBloc,
                apiClient: app.apiClient,
                recordId: '7',
                preloadedGoal: Goal(
                  id: '7',
                  name: 'Read 12 books',
                  startDate: DateTime.utc(2026, 1, 1),
                  target: 12,
                  unit: 'books',
                ),
              ),
              submitLabel: 'Save goal',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit goal'), findsOneWidget);
    expect(find.text('Save goal'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);

    app.dispose();
  });
}
