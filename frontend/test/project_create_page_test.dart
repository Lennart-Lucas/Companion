import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/pages/project_create_page.dart';

void main() {
  testWidgets('ProjectCreatePage shows create project form', (
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
          home: const ProjectCreatePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New project'), findsOneWidget);
    expect(find.text('Create project'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Schedule & status'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);

    app.dispose();
  });
}
