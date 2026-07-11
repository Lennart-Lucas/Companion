import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/goals/pages/goal_detail_page.dart';
import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/goals/services/goal_list_actions.dart';

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
      const [];

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
        checkInAt: DateTime.utc(2026, 6, 10),
        goalType: GoalType.task,
        logged: completed != null,
        completed: completed,
      );
}

void main() {
  testWidgets('GoalDetailPage shows goal name and stats section', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    final goal = Goal(
      id: '1',
      name: 'Read 12 books',
      goalType: GoalType.count,
      target: 12,
      unit: 'books',
      direction: GoalDirection.increasing,
      startDate: DateTime.utc(2026, 1, 1),
    );

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
          home: GoalDetailPage(
            goalId: goal.id,
            goal: goal,
            goalActions: _FakeGoalListActions(),
            checkInRepository: _FakeGoalCheckInRepository(),
            initialCheckIns: const [],
            listToday: DateTime.utc(2026, 6, 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read 12 books'), findsWidgets);
    expect(find.text('Books over time'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Trackers'), findsOneWidget);

    app.dispose();
  });
}
