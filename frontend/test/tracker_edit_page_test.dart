import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_edit_page.dart';

import 'support/companion_test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestCompanionAnvilApp();
  });

  tearDownAll(() async {
    await disposeTestCompanionAnvilApp();
  });

  testWidgets('TrackerEditPage shows edit tracker form', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();

    final authBloc = CompanionAnvilApp.instance.authBloc;
    final recordBloc = CompanionAnvilApp.instance.recordBloc;

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<RecordBloc>.value(value: recordBloc),
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
    await pumpUntilFound(tester, find.text('Save tracker'), maxPumps: 100);

    expect(find.text('Edit tracker'), findsOneWidget);
    expect(find.text('Save tracker'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
