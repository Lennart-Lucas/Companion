import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/goals/forms/goal_form_config.dart';

void main() {
  testWidgets('GoalCreatePage shows create goal form', (
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
            appBar: AppBar(title: const Text('New goal')),
            body: AnvilForm(
              config: buildGoalFormConfig(
                app.recordBloc,
                apiClient: app.apiClient,
              ),
              submitLabel: 'Create goal',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New goal'), findsOneWidget);
    expect(find.text('Create goal'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Milestones'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);

    app.dispose();
  });
}
