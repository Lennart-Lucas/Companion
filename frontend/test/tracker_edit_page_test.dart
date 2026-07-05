import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/pages/tracker_edit_page.dart';

void main() {
  testWidgets('TrackerEditPage shows edit tracker form', (
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
          home: TrackerEditPage(
            trackerId: '7',
            tracker: Tracker(
              id: '7',
              name: 'Water intake',
              startDate: DateTime.utc(2026, 6, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit tracker'), findsOneWidget);
    expect(find.text('Save tracker'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('Tracking'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);

    app.dispose();
  });
}
