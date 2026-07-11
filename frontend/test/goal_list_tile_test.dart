import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/goals/models/goal_milestone.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';

import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/goals/services/goal_list_actions.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_list_tile.dart';

class _FakeGoalListActions implements GoalListTileActions {
  @override
  Future<void> copyGoal(Goal goal) async {}

  @override
  Future<void> deleteGoal(String goalId) async {}
}

class _FakeGoalCheckInRepository implements GoalCheckInRepository {
  @override
  Future<List<GoalCheckIn>> fetchCheckIns(
    String goalId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  }) async =>
      const [];

  @override
  Future<List<GoalCheckIn>> fetchGoalHistory(
    Goal goal, {
    DateTime? now,
    int maxCount = 5000,
  }) async =>
      [
        GoalCheckIn(
          id: 1,
          checkInAt: DateTime.utc(2026, 6, 9),
          goalType: GoalType.count,
          logged: true,
          countValue: 6,
        ),
      ];

  @override
  Future<List<GoalCheckIn>> fetchCheckInsForDay(
    String goalId,
    DateTime day, {
    int maxCount = 100,
  }) async =>
      const [];

  @override
  Future<GoalCheckIn> updateCheckIn(
    String goalId,
    int checkInId, {
    bool? completed,
    num? countValue,
  }) async =>
      GoalCheckIn(
        id: checkInId,
        checkInAt: DateTime.utc(2026, 6, 9),
        goalType: GoalType.count,
        logged: true,
        countValue: countValue,
      );
}

void main() {
  setUp(setupCompanionIcons);

  Widget wrap(Goal goal) {
    final app = AnvilApp(
      baseUrl: 'http://mock.local/api/v1',
      tokenStorage: InMemoryTokenStorage(),
      recordRegistry: buildCompanionRecordRegistry(),
      httpClient: MockHttpClientService(baseUrl: 'http://mock.local/api/v1'),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: app.authBloc!),
        BlocProvider<RecordBloc>.value(value: app.recordBloc),
      ],
      child: MaterialApp(
        theme: theHubTheme,
        home: Scaffold(
          body: GoalListTile(
            goal: goal,
            actions: _FakeGoalListActions(),
            checkInRepository: _FakeGoalCheckInRepository(),
            listToday: DateTime.utc(2026, 6, 10),
          ),
        ),
      ),
    );
  }

  testWidgets('GoalListTile shows name and chips', (WidgetTester tester) async {
    final goal = Goal(
      id: '1',
      name: 'Read 12 books',
      goalType: GoalType.count,
      target: 12,
      unit: 'books',
      direction: GoalDirection.increasing,
      startDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2026, 12, 31),
      color: '#3366FF',
      icon: 'Bullseye',
      milestones: const [
        GoalMilestone(value: 3, sortOrder: 0),
        GoalMilestone(value: 6, sortOrder: 1),
      ],
    );

    await tester.pumpWidget(wrap(goal));
    await tester.pumpAndSettle();

    expect(find.text('Read 12 books'), findsOneWidget);
    expect(find.text('12 books'), findsOneWidget);
    expect(find.text('Increasing'), findsOneWidget);
    expect(find.text('2 milestones'), findsOneWidget);
    expect(find.textContaining('%'), findsOneWidget);
  });

  testWidgets('GoalListTile shows task type', (WidgetTester tester) async {
    final goal = Goal(
      id: '2',
      name: 'Weekly workouts',
      goalType: GoalType.task,
      target: 4,
      unit: 'sessions',
      direction: GoalDirection.increasing,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(wrap(goal));
    await tester.pumpAndSettle();

    expect(find.text('Weekly workouts'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
  });
}
