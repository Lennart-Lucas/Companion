import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/shared/services/weekly_summary_service.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';

class _FakeTaskBuilder extends TaskListBuilder {
  _FakeTaskBuilder(this.entries) : super(_ThrowingApiClient());

  final List<TaskListEntry> entries;

  @override
  Future<List<TaskListEntry>> build(
    List<Task> tasks, {
    TaskListHorizon? horizon,
  }) async {
    return entries;
  }
}

class _ThrowingApiClient implements ApiClientService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGoalCheckInRepository implements GoalCheckInRepository {
  _FakeGoalCheckInRepository(this.checkInsByGoal);

  final Map<String, List<GoalCheckIn>> checkInsByGoal;

  @override
  Future<List<GoalCheckIn>> fetchCheckIns(
    String goalId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  }) async {
    return checkInsByGoal[goalId] ?? const [];
  }

  @override
  Future<GoalCheckIn> updateCheckIn(
    String goalId,
    int checkInId, {
    bool? completed,
    num? countValue,
  }) => throw UnimplementedError();

  @override
  Future<List<GoalCheckIn>> fetchGoalHistory(
    Goal goal, {
    DateTime? now,
    int maxCount = 5000,
  }) async {
    return checkInsByGoal[goal.id] ?? const [];
  }

  @override
  Future<List<GoalCheckIn>> fetchCheckInsForDay(
    String goalId,
    DateTime day, {
    int maxCount = 100,
  }) async {
    return const [];
  }
}

class _FakeTrackerCheckInRepository implements TrackerCheckInRepository {
  _FakeTrackerCheckInRepository(this.checkInsByTracker);

  final Map<String, List<TrackerCheckIn>> checkInsByTracker;

  @override
  Future<List<TrackerCheckIn>> fetchCheckIns(
    String trackerId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  }) async {
    final all = checkInsByTracker[trackerId] ?? const [];
    return all
        .where(
          (checkIn) =>
              !checkIn.checkInAt.isBefore(from) &&
              !checkIn.checkInAt.isAfter(to),
        )
        .toList();
  }

  @override
  Future<TrackerCheckIn> createCheckIn(
    String trackerId, {
    required DateTime checkInAt,
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    DateTime? timerStartedAt,
    bool skipped = false,
  }) => throw UnimplementedError();

  @override
  Future<List<TrackerCheckIn>> fetchCheckInsForDay(
    String trackerId,
    DateTime day, {
    int maxCount = 100,
  }) async {
    final all = checkInsByTracker[trackerId] ?? const [];
    final normalized = normalizeTaskListCalendarDay(day);
    return all
        .where(
          (checkIn) =>
              normalizeTaskListCalendarDay(checkIn.checkInAt.toLocal()) ==
              normalized,
        )
        .toList();
  }

  @override
  Future<List<TrackerCheckIn>> fetchTrackerHistory(
    Tracker tracker, {
    DateTime? now,
    int maxCount = 5000,
  }) async {
    final all = checkInsByTracker[tracker.id] ?? const [];
    final reference = now ?? DateTime.now();
    final referenceDay = normalizeTaskListCalendarDay(reference);
    final referenceEnd = DateTime(
      referenceDay.year,
      referenceDay.month,
      referenceDay.day,
      23,
      59,
      59,
      999,
    );
    return all
        .where((checkIn) => !checkIn.checkInAt.isAfter(referenceEnd))
        .toList();
  }

  @override
  Future<void> skipCheckIn(String trackerId, int checkInId) =>
      throw UnimplementedError();

  @override
  Future<TrackerCheckIn> updateCheckIn(
    String trackerId,
    int checkInId, {
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    DateTime? timerStartedAt,
    bool skipped = false,
  }) => throw UnimplementedError();
}

RecordState _stateWithRecords({
  required List<Goal> goals,
  required List<Tracker> trackers,
  required List<Project> projects,
}) {
  final now = DateTime.utc(2026, 7, 7);
  final records = <String, RecordCached>{};
  for (final record in [...goals, ...trackers, ...projects]) {
    records[record.id] = RecordCached(
      record: record,
      version: 1,
      origin: RecordOrigin.network,
      freshness: RecordFreshness.fresh,
      expiresAt: now.add(const Duration(hours: 1)),
      lastUpdatedAt: now,
      lastFetchedAt: now,
    );
  }

  return RecordState(
    RecordCacheSnapshot(
      offline: false,
      errors: const [],
      records: records,
      queries: {
        const RecordQuery(
          recordType: 'tasks',
          limit: 50,
        ).queryKey: CachedQueryResult(
          recordIds: const [],
          version: 1,
          freshness: RecordFreshness.fresh,
          expiresAt: now.add(const Duration(hours: 1)),
          lastUpdatedAt: now,
          lastFetchedAt: now,
        ),
        const RecordQuery(
          recordType: 'goals',
          limit: 50,
        ).queryKey: CachedQueryResult(
          recordIds: goals.map((goal) => goal.id).toList(),
          version: 1,
          freshness: RecordFreshness.fresh,
          expiresAt: now.add(const Duration(hours: 1)),
          lastUpdatedAt: now,
          lastFetchedAt: now,
        ),
        const RecordQuery(
          recordType: 'trackers',
          limit: 50,
        ).queryKey: CachedQueryResult(
          recordIds: trackers.map((tracker) => tracker.id).toList(),
          version: 1,
          freshness: RecordFreshness.fresh,
          expiresAt: now.add(const Duration(hours: 1)),
          lastUpdatedAt: now,
          lastFetchedAt: now,
        ),
        const RecordQuery(
          recordType: 'projects',
          limit: 50,
        ).queryKey: CachedQueryResult(
          recordIds: projects.map((project) => project.id).toList(),
          version: 1,
          freshness: RecordFreshness.fresh,
          expiresAt: now.add(const Duration(hours: 1)),
          lastUpdatedAt: now,
          lastFetchedAt: now,
        ),
      },
    ),
  );
}

void main() {
  group('WeeklySummaryService', () {
    final weekStart = DateTime(2026, 7, 6);
    final completedTask = Task(
      id: 't1',
      name: 'Ship feature',
      projectId: 'p1',
      plannedAt: DateTime(2026, 7, 8),
      updatedAt: DateTime(2026, 7, 8, 16),
    );
    final completedEntry = TaskListEntry(
      task: completedTask,
      status: 'completed',
      priority: 'normal',
      subtasks: const [],
      isVirtual: false,
      displayAt: DateTime(2026, 7, 8),
      resolvedAt: DateTime(2026, 7, 8, 16),
    );

    test(
      'aggregates tasks, goals, trackers, and projects for a week',
      () async {
        final goal = Goal(
          id: 'g1',
          name: 'Read books',
          startDate: DateTime.utc(2026, 1, 1),
          target: 12,
          unit: 'books',
        );
        final tracker = Tracker(
          id: 'tr1',
          name: 'Exercise',
          startDate: DateTime.utc(2026, 1, 1),
          checkInType: TrackerCheckInType.task,
          habitDirection: TrackerHabitDirection.build,
        );
        final project = Project(
          id: 'p1',
          name: 'Companion',
          startDate: DateTime.utc(2026, 1, 1),
          status: 'active',
        );

        final service = WeeklySummaryService(
          taskBuilder: _FakeTaskBuilder([completedEntry]),
          goalCheckInRepository: _FakeGoalCheckInRepository({
            'g1': [
              GoalCheckIn(
                id: 1,
                checkInAt: DateTime(2026, 7, 7),
                goalType: GoalType.count,
                logged: true,
              ),
              GoalCheckIn(
                id: 2,
                checkInAt: DateTime(2026, 7, 8),
                goalType: GoalType.count,
                logged: false,
              ),
            ],
          }),
          trackerCheckInRepository: _FakeTrackerCheckInRepository({
            'tr1': [
              TrackerCheckIn(
                id: 1,
                checkInAt: DateTime(2026, 7, 7),
                checkInType: TrackerCheckInType.task,
                logged: true,
                skipped: false,
                completed: true,
              ),
              TrackerCheckIn(
                id: 2,
                checkInAt: DateTime(2026, 7, 9),
                checkInType: TrackerCheckInType.task,
                logged: false,
                skipped: false,
              ),
            ],
          }),
        );

        final summary = await service.compute(
          state: _stateWithRecords(
            goals: [goal],
            trackers: [tracker],
            projects: [project],
          ),
          weekStart: weekStart,
        );

        expect(summary.tasks.completed, 1);
        expect(summary.tasks.completedEntries.single.task.name, 'Ship feature');
        expect(summary.goals.single.logged, 1);
        expect(summary.goals.single.total, 2);
        expect(summary.goals.single.progressPercent, greaterThanOrEqualTo(0));
        expect(summary.trackers.single.succeeded, 1);
        expect(summary.trackers.single.missed, 1);
        expect(summary.trackers.single.dayOutcomes, isNotEmpty);
        expect(summary.projects.single.tasksCompleted, 1);
        expect(summary.projects.single.tasksTotal, 1);
        expect(summary.projects.single.taskEntries, hasLength(1));
        expect(summary.recap.checkInsLogged, 2);
        expect(summary.recap.tasksCompleted, 1);
        expect(summary.recap.consistencyPercent, closeTo(0.5, 0.01));
      },
    );

    test('includes today UTC check-in in week day outcomes for current week', () async {
      final tracker = Tracker(
        id: 'tr1',
        name: 'Make a day plan',
        startDate: DateTime.utc(2026, 1, 1),
        checkInType: TrackerCheckInType.task,
        habitDirection: TrackerHabitDirection.build,
      );
      final weekStart = DateTime(2026, 7, 13);
      final todayUtcMidnight = DateTime.utc(2026, 7, 13);

      final service = WeeklySummaryService(
        taskBuilder: _FakeTaskBuilder(const []),
        goalCheckInRepository: _FakeGoalCheckInRepository({}),
        trackerCheckInRepository: _FakeTrackerCheckInRepository({
          'tr1': [
            TrackerCheckIn(
              id: 1,
              checkInAt: todayUtcMidnight,
              checkInType: TrackerCheckInType.task,
              logged: true,
              skipped: false,
              completed: true,
            ),
          ],
        }),
      );

      final summary = await service.compute(
        state: _stateWithRecords(
          goals: const [],
          trackers: [tracker],
          projects: const [],
        ),
        weekStart: weekStart,
        listToday: weekStart,
      );

      final trackerSummary = summary.trackers.single;
      expect(trackerSummary.loggedToday, isTrue);
      expect(trackerSummary.succeeded, 1);
      expect(
        trackerSummary.dayOutcomes[normalizeTaskListCalendarDay(weekStart)],
        TrackerDayOutcome.succeeded,
      );
    });
  });
}
