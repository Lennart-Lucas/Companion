import 'package:frontend/core/formatting/week_calendar.dart';

import 'package:anvil_foundry/anvil_foundry.dart';

import 'package:frontend/core/app/companion_anvil_app.dart';

import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/core/records/typed_record_resolver.dart';

import 'package:frontend/features/productivity/goals/models/goal.dart';

import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';

import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';

import 'package:frontend/features/productivity/goals/services/goal_stats.dart';

import 'package:frontend/features/productivity/projects/models/project.dart';

import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';

import 'package:frontend/features/productivity/shared/services/productivity_date_range.dart';
import 'package:frontend/features/productivity/shared/services/timeline_feed.dart';
import 'package:frontend/features/productivity/shared/services/weekly_summary_timeline.dart';

import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';

import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';

import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';

import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';

import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';

/// Builds full weekly dashboard snapshots from cached records and check-ins.

class WeeklySummaryService {
  WeeklySummaryService({
    TaskListBuilder? taskBuilder,

    GoalCheckInRepository? goalCheckInRepository,

    TrackerCheckInRepository? trackerCheckInRepository,
  }) : _taskBuilder =
           taskBuilder ?? TaskListBuilder(CompanionAnvilApp.instance.apiClient),

       _goalCheckInRepository =
           goalCheckInRepository ?? defaultGoalCheckInRepository(),

       _trackerCheckInRepository =
           trackerCheckInRepository ?? defaultTrackerCheckInRepository();

  final TaskListBuilder _taskBuilder;

  final GoalCheckInRepository _goalCheckInRepository;

  final TrackerCheckInRepository _trackerCheckInRepository;

  Future<WeeklySummary> compute({
    required RecordState state,

    required DateTime weekStart,

    DateTime? listToday,
  }) async {
    final normalizedWeekStart = normalizeTaskListCalendarDay(weekStart);

    final weekEnd = taskListWeekEnd(normalizedWeekStart);

    final referenceDay = normalizeTaskListCalendarDay(
      listToday ?? DateTime.now(),
    );

    final isCurrentWeek = taskListWeekIsCurrent(
      normalizedWeekStart,
      now: referenceDay,
    );

    final statsReference = isCurrentWeek ? referenceDay : weekEnd;

    final horizon = TaskListHorizon.forLocalDays(normalizedWeekStart, weekEnd);

    final tasks = await _resolveTasks(state);

    final taskEntries = await _taskBuilder.build(tasks, horizon: horizon);

    final taskSummary = _computeTaskSummary(
      taskEntries,

      normalizedWeekStart,

      weekEnd,
    );

    final goals = await _resolveGoals(state);

    final activeGoals = goals
        .where((goal) => goalActiveInRange(goal, normalizedWeekStart, weekEnd))
        .toList();

    final goalSummaries = await Future.wait(
      activeGoals.map(
        (goal) => _computeGoalSummary(
          goal,

          weekFrom: horizon.from,

          weekTo: horizon.to,

          statsReference: statsReference,

          today: isCurrentWeek ? referenceDay : null,
        ),
      ),
    );

    final trackers = await _resolveTrackers(state);

    final activeTrackers = trackers
        .where(
          (tracker) =>
              trackerActiveInRange(tracker, normalizedWeekStart, weekEnd),
        )
        .toList();

    final trackerSummaries = await Future.wait(
      activeTrackers.map(
        (tracker) => _computeTrackerSummary(
          tracker,

          weekFrom: horizon.from,

          weekTo: horizon.to,

          weekStart: normalizedWeekStart,

          statsReference: statsReference,

          today: isCurrentWeek ? referenceDay : null,
        ),
      ),
    );

    final projects = await _resolveProjects(state);

    final activeProjects = projects
        .where(
          (project) => projectActiveInRange(
            project,
            normalizedWeekStart,
            weekEnd,
          ),
        )
        .toList();

    final projectSummaries = _computeProjectSummaries(
      projects: activeProjects,

      taskEntries: taskEntries,

      weekStart: normalizedWeekStart,

      weekEnd: weekEnd,
    );

    final recap = _computeRecapStats(
      taskSummary: taskSummary,
      goals: goalSummaries,
      trackers: trackerSummaries,
      statsReference: statsReference,
    );

    return WeeklySummary(
      weekStart: normalizedWeekStart,

      recap: recap,

      tasks: taskSummary,

      goals: goalSummaries,

      trackers: trackerSummaries,

      projects: projectSummaries,
    );
  }

  WeeklyRecapStats _computeRecapStats({
    required WeeklyTaskSummary taskSummary,
    required List<WeeklyGoalSummary> goals,
    required List<WeeklyTrackerSummary> trackers,
    required DateTime statsReference,
  }) {
    final checkInsLogged =
        goals.fold<int>(0, (sum, g) => sum + g.logged) +
        trackers.fold<int>(0, (sum, t) => sum + t.succeeded);

    var goalsOnTrack = 0;

    for (final goal in goals) {
      final pace = computeGoalPace(
        goal.goal,

        goal.progressPercent,

        now: statsReference,
      );

      if (pace == GoalPace.onTrack || pace == GoalPace.ahead) {
        goalsOnTrack++;
      }
    }

    var trackersOnStreak = 0;

    for (final tracker in trackers) {
      if (tracker.currentStreak > 0) trackersOnStreak++;
    }

    var goalCompleted = 0;

    var goalScheduled = 0;

    for (final goal in goals) {
      goalCompleted += goal.logged;

      goalScheduled += goal.total;
    }

    var trackerCompleted = 0;

    var trackerScheduled = 0;

    for (final tracker in trackers) {
      trackerCompleted += tracker.succeeded;

      trackerScheduled += tracker.succeeded + tracker.missed;
    }

    final totalCompleted = goalCompleted + trackerCompleted;

    final totalScheduled = goalScheduled + trackerScheduled;

    final consistencyPercent = totalScheduled == 0
        ? 0.0
        : totalCompleted / totalScheduled;

    return WeeklyRecapStats(
      checkInsLogged: checkInsLogged,

      tasksCompleted: taskSummary.completed,

      trackersOnStreak: trackersOnStreak,

      trackersTotal: trackers.length,

      goalsOnTrack: goalsOnTrack,

      goalsTotal: goals.length,

      consistencyPercent: consistencyPercent,
    );
  }

  WeeklyTaskSummary _computeTaskSummary(
    List<TaskListEntry> entries,

    DateTime weekStart,

    DateTime weekEnd,
  ) {
    final inWeek = entries
        .where((entry) => taskEntryInWeek(entry, weekStart, weekEnd))
        .toList();

    final completedEntries = <TaskListEntry>[];

    var planned = 0;

    var overdue = 0;

    for (final entry in inWeek) {
      if (entry.status == 'completed') {
        final resolved =
            entry.resolvedAt ?? entry.displayAt ?? entry.task.updatedAt;

        if (resolved != null && _dayInWeek(resolved, weekStart, weekEnd)) {
          completedEntries.add(entry);
        }

        continue;
      }

      planned++;

      if (entry.isPastDue) overdue++;
    }

    return WeeklyTaskSummary(
      completed: completedEntries.length,

      planned: planned,

      overdue: overdue,

      completedEntries: completedEntries,
    );
  }

  Future<WeeklyGoalSummary> _computeGoalSummary(
    Goal goal, {

    required DateTime weekFrom,

    required DateTime weekTo,

    required DateTime statsReference,

    DateTime? today,
  }) async {
    final weekCheckIns = await _goalCheckInRepository.fetchCheckIns(
      goal.id,

      from: weekFrom,

      to: weekTo,
    );

    final history = await _goalCheckInRepository.fetchGoalHistory(
      goal,

      now: statsReference,
    );

    final stats = computeGoalStats(goal, history, now: statsReference);

    final logged = weekCheckIns
        .where((c) => classifyGoalCheckIn(c) == GoalCheckInOutcome.logged)
        .length;

    final total = weekCheckIns.length;

    DateTime? lastCheckInAt;

    for (final checkIn in history.reversed) {
      if (classifyGoalCheckIn(checkIn) == GoalCheckInOutcome.logged) {
        lastCheckInAt = checkIn.checkInAt;

        break;
      }
    }

    GoalCheckIn? todayCheckIn;

    var loggedToday = false;

    if (today != null) {
      final todayCheckIns = await _goalCheckInRepository.fetchCheckInsForDay(
        goal.id,

        today,
      );

      if (todayCheckIns.isNotEmpty) {
        todayCheckIn = todayCheckIns.first;

        loggedToday = todayCheckIns.any(
          (c) => classifyGoalCheckIn(c) == GoalCheckInOutcome.logged,
        );
      }
    }

    return WeeklyGoalSummary(
      goal: goal,

      loggedRate: total == 0 ? 0 : logged / total,

      logged: logged,

      total: total,

      progressPercent: stats.progressPercent,

      consistency: stats.consistency,

      currentStreak: stats.currentStreak,

      lastCheckInAt: lastCheckInAt,

      loggedToday: loggedToday,

      todayCheckIn: todayCheckIn,
    );
  }

  Future<WeeklyTrackerSummary> _computeTrackerSummary(
    Tracker tracker, {

    required DateTime weekFrom,

    required DateTime weekTo,

    required DateTime weekStart,

    required DateTime statsReference,

    DateTime? today,
  }) async {
    final weekCheckIns = await _trackerCheckInRepository.fetchCheckIns(
      tracker.id,

      from: weekFrom,

      to: weekTo,
    );

    final history = await _trackerCheckInRepository.fetchTrackerHistory(
      tracker,

      now: statsReference,
    );

    final stats = computeTrackerStats(tracker, history, now: statsReference);

    var succeeded = 0;

    var missed = 0;

    for (final checkIn in weekCheckIns) {
      switch (classifyTrackerCheckIn(tracker, checkIn, now: statsReference)) {
        case TrackerCheckInOutcome.succeeded:
          succeeded++;

        case TrackerCheckInOutcome.missed:
          missed++;

        case TrackerCheckInOutcome.skipped:
        case TrackerCheckInOutcome.pending:
          break;
      }
    }

    final denominator = succeeded + missed;

    final weekDays = taskListWeekDays(weekStart);

    final weekDayOutcomes = <DateTime, TrackerDayOutcome>{};

    for (final day in weekDays) {
      final outcome = trackerDayOutcomeOn(stats.dayOutcomes, day);

      if (outcome != null) {
        weekDayOutcomes[day] = outcome;
      }
    }

    var weekSucceeded = 0;

    var weekResolved = 0;

    for (final outcome in weekDayOutcomes.values) {
      switch (outcome) {
        case TrackerDayOutcome.succeeded:
          weekSucceeded++;

          weekResolved++;

        case TrackerDayOutcome.missed:
          weekResolved++;

        case TrackerDayOutcome.skipped:
        case TrackerDayOutcome.pending:
          break;
      }
    }

    final thisWeekPercent = weekResolved == 0
        ? 0.0
        : weekSucceeded / weekResolved;

    TrackerCheckIn? todayCheckIn;

    var loggedToday = false;

    if (today != null) {
      final todayCheckIns = await _trackerCheckInRepository.fetchCheckInsForDay(
        tracker.id,

        today,
      );

      if (todayCheckIns.isNotEmpty) {
        todayCheckIn = todayCheckIns.first;

        loggedToday = todayCheckIns.any(
          (c) =>
              classifyTrackerCheckIn(tracker, c, now: today) ==
              TrackerCheckInOutcome.succeeded,
        );
      }
    }

    return WeeklyTrackerSummary(
      tracker: tracker,

      successRate: denominator == 0 ? 0 : succeeded / denominator,

      succeeded: succeeded,

      missed: missed,

      dayOutcomes: weekDayOutcomes,

      thisWeekPercent: thisWeekPercent,

      currentStreak: stats.currentStreak,

      loggedToday: loggedToday,

      todayCheckIn: todayCheckIn,
    );
  }

  List<WeeklyProjectSummary> _computeProjectSummaries({
    required List<Project> projects,

    required List<TaskListEntry> taskEntries,

    required DateTime weekStart,

    required DateTime weekEnd,
  }) {
    const maxTaskEntries = 8;

    final summaries = <WeeklyProjectSummary>[];

    for (final project in projects) {
      final projectEntries = taskEntries
          .where((entry) => entry.task.projectId == project.id)
          .where((entry) => taskEntryInWeek(entry, weekStart, weekEnd))
          .toList();

      var completed = 0;

      for (final entry in projectEntries) {
        if (entry.status == 'completed') completed++;
      }

      projectEntries.sort((a, b) {
        final aDone = a.status == 'completed';

        final bDone = b.status == 'completed';

        if (aDone != bDone) return aDone ? 1 : -1;

        return (a.displayAt ?? a.task.plannedAt ?? DateTime(1970)).compareTo(
          b.displayAt ?? b.task.plannedAt ?? DateTime(1970),
        );
      });

      summaries.add(
        WeeklyProjectSummary(
          project: project,

          tasksCompleted: completed,

          tasksTotal: projectEntries.length,

          taskEntries: projectEntries.take(maxTaskEntries).toList(),
        ),
      );
    }

    summaries.sort((a, b) => b.tasksTotal.compareTo(a.tasksTotal));

    return summaries;
  }

  bool _dayInWeek(DateTime day, DateTime weekStart, DateTime weekEnd) {
    final normalized = normalizeTaskListCalendarDay(day);
    return !normalized.isBefore(weekStart) && !normalized.isAfter(weekEnd);
  }

  Future<List<Task>> _resolveTasks(RecordState state) async {
    return _resolveRecordsFromState<Task>(
      state,
      TaskTimelineProvider.tasksQuery,
    );
  }

  Future<List<Goal>> _resolveGoals(RecordState state) async {
    return _resolveRecordsFromState<Goal>(
      state,
      GoalTimelineProvider.goalsQuery,
    );
  }

  Future<List<Tracker>> _resolveTrackers(RecordState state) async {
    return _resolveRecordsFromState<Tracker>(
      state,
      TrackerTimelineProvider.trackersQuery,
    );
  }

  Future<List<Project>> _resolveProjects(RecordState state) async {
    return _resolveRecordsFromState<Project>(
      state,
      const RecordQuery(recordType: 'projects', limit: 50),
    );
  }

  Future<List<T>> _resolveRecordsFromState<T extends ProductivityRecord>(
    RecordState state,
    RecordQuery query,
  ) async {
    final cached = state.snapshot.queries[query.queryKey];
    if (cached == null) return const [];

    var records = cached.recordIds
        .map((id) => state.snapshot.records[id]?.record)
        .whereType<T>()
        .toList();

    if (records.length == cached.recordIds.length) {
      return records;
    }

    records = await resolveTypedRecords<T>(
      state: state,
      recordType: query.recordType,
      recordIds: cached.recordIds,
      cache: CompanionAnvilApp.instance.localCache,
      registry: buildCompanionRecordRegistry(),
    );
    return records;
  }
}
