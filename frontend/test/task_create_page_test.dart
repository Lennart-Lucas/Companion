import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/tasks/forms/task_form_config.dart';

void main() {
  testWidgets('TaskCreatePage shows create task wizard', (WidgetTester tester) async {
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
            appBar: AppBar(title: const Text('New task')),
            body: AnvilFormWizard(
              config: buildTaskFormConfig(
                app.recordBloc,
                apiClient: app.apiClient,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('When & status'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    app.dispose();
  });
}
