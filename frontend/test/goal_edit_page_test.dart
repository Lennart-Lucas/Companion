import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/goals/pages/goal_edit_page.dart';

import 'support/companion_test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestCompanionAnvilApp();
  });

  tearDownAll(() async {
    await disposeTestCompanionAnvilApp();
  });

  testWidgets('GoalEditPage shows edit goal form', (
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
          home: GoalEditPage(
            goalId: '7',
            goal: Goal(
              id: '7',
              name: 'Read 12 books',
              startDate: DateTime.utc(2026, 1, 1),
              target: 12,
              unit: 'books',
            ),
          ),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Save goal'));

    expect(find.text('Edit goal'), findsOneWidget);
    expect(find.text('Save goal'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
