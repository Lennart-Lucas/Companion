import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/shared/pages/weekly_summary_page.dart';
import 'package:frontend/features/productivity/shared/services/weekly_summary_service.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';

class _FakeWeeklySummaryService extends WeeklySummaryService {
  _FakeWeeklySummaryService(this.summary)
    : super(
        taskBuilder: _NoopTaskBuilder(),
        goalCheckInRepository: _NoopGoalCheckInRepository(),
        trackerCheckInRepository: _NoopTrackerCheckInRepository(),
      );

  final WeeklySummary summary;

  @override
  Future<WeeklySummary> compute({
    required RecordState state,
    required DateTime weekStart,
    DateTime? listToday,
  }) async {
    return WeeklySummary(
      weekStart: weekStart,
      recap: summary.recap,
      tasks: summary.tasks,
      goals: summary.goals,
      trackers: summary.trackers,
      projects: summary.projects,
    );
  }
}

class _NoopTaskBuilder extends TaskListBuilder {
  _NoopTaskBuilder() : super(_ThrowingApiClient());

  @override
  Future<List<TaskListEntry>> build(
    List<Task> tasks, {
    TaskListHorizon? horizon,
  }) async => const [];
}

class _ThrowingApiClient implements ApiClientService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoopGoalCheckInRepository implements GoalCheckInRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoopTrackerCheckInRepository implements TrackerCheckInRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

RecordBloc _createRecordBloc() {
  final mockHttp = MockHttpClientService(
    baseUrl: 'http://mock.local/api/v1',
    delay: Duration.zero,
  );
  final api = ApiClientService(mockHttp);
  final repo = HttpRecordRepositoryService(api);
  final coordinator = RecordCoordinatorService(
    buildCompanionRecordRegistry(),
    repo,
  );
  return RecordBloc(coordinator);
}

void main() {
  group('WeeklySummaryPage', () {
    testWidgets('renders dashboard sections and week navigation', (
      tester,
    ) async {
      final weekStart = DateTime(2026, 7, 6);
      final summary = WeeklySummary(
        weekStart: weekStart,
        recap: const WeeklyRecapStats(
          checkInsLogged: 18,
          tasksCompleted: 9,
          trackersOnStreak: 2,
          trackersTotal: 3,
          goalsOnTrack: 2,
          goalsTotal: 3,
          consistencyPercent: 0.74,
        ),
        tasks: const WeeklyTaskSummary(
          completed: 9,
          planned: 1,
          overdue: 0,
          completedEntries: [],
        ),
        goals: const [],
        trackers: const [],
        projects: const [],
      );
      final recordBloc = _createRecordBloc();
      addTearDown(recordBloc.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<RecordBloc>.value(
            value: recordBloc,
            child: WeeklySummaryPage(
              weekStart: weekStart,
              listToday: DateTime(2026, 7, 13),
              summaryService: _FakeWeeklySummaryService(summary),
              goalCheckInRepository: _NoopGoalCheckInRepository(),
              trackerCheckInRepository: _NoopTrackerCheckInRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Jul 6 – 12, 2026'), findsOneWidget);
      expect(find.text('LAST WEEK RECAP'), findsOneWidget);
      expect(find.text('Check-ins logged'), findsOneWidget);
      expect(find.text('Tasks completed'), findsOneWidget);
      expect(find.text('Trackers on-streak'), findsOneWidget);
      expect(find.text('Goals on track'), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);
      expect(find.text('What went well last week?'), findsOneWidget);
      expect(find.text('Plan for this week'), findsOneWidget);
      expect(find.text('No goal activity this week'), findsOneWidget);
      expect(find.text('View all >'), findsNWidgets(3));

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('No tracker activity this week'),
        120,
        scrollable: scrollable,
      );
      expect(find.text('No tracker activity this week'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('No active projects this week'),
        120,
        scrollable: scrollable,
      );
      expect(find.text('No active projects this week'), findsOneWidget);

      expect(find.byType(TrackerProgressRing), findsNWidgets(5));
      expect(find.text('18'), findsNWidgets(2));
      expect(find.text('74%'), findsNWidgets(2));
      expect(find.text('Today'), findsOneWidget);
    });
  });
}
