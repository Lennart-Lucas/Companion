import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/pages/tracker_create_page.dart';

void main() {
  testWidgets('TrackerCreatePage shows create tracker form', (
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
          home: const TrackerCreatePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New tracker'), findsOneWidget);
    expect(find.text('Create tracker'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('Tracking'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Recurrence for this tracker'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Repeat mode'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Start date'), findsOneWidget);
    expect(find.textContaining('Repeat mode'), findsOneWidget);

    app.dispose();
  });
}
