import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/offline_task_context.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/typed_record_resolver.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/shared/models/timeline_item.dart';
import 'package:frontend/features/productivity/shared/services/productivity_date_range.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';

/// Loads one kind of content into the productivity timeline.
abstract class TimelineContentProvider {
  const TimelineContentProvider();

  /// Queries to prefetch when the timeline mounts.
  List<RecordQuery> get prefetchQueries;

  /// Primary query whose version bumps trigger a timeline refresh.
  RecordQuery? get watchQuery;

  Future<List<TimelineSortableItem>> load(
    RecordState state,
    TaskListHorizon horizon,
  );
}

/// Merges timeline content from multiple providers.
class ProductivityTimelineFeed {
  const ProductivityTimelineFeed({required this.providers});

  final List<TimelineContentProvider> providers;

  List<RecordQuery> get prefetchQueries => [
        for (final provider in providers) ...provider.prefetchQueries,
      ];

  Iterable<RecordQuery> get watchQueries => providers
      .map((provider) => provider.watchQuery)
      .whereType<RecordQuery>();

  Future<List<TimelineSortableItem>> load(
    RecordState state,
    TaskListHorizon horizon,
  ) async {
    if (providers.isEmpty) return const [];

    final batches = await Future.wait(
      providers.map((provider) => provider.load(state, horizon)),
    );
    return batches.expand((batch) => batch).toList();
  }
}

/// Default feed with tasks only (events can be added later).
ProductivityTimelineFeed defaultProductivityTimelineFeed({
  ApiClientService? apiClient,
  OfflineTaskContext? offlineContext,
}) {
  return ProductivityTimelineFeed(
    providers: [
      TaskTimelineProvider(
        apiClient: apiClient,
        offlineContext: offlineContext,
      ),
    ],
  );
}

/// Overview feed with tasks and tracker check-in moments.
ProductivityTimelineFeed overviewProductivityTimelineFeed({
  ApiClientService? apiClient,
  OfflineTaskContext? offlineContext,
  TrackerCheckInRepository? checkInRepository,
  GoalCheckInRepository? goalCheckInRepository,
}) {
  return ProductivityTimelineFeed(
    providers: [
      TaskTimelineProvider(
        apiClient: apiClient,
        offlineContext: offlineContext,
      ),
      TrackerTimelineProvider(
        apiClient: apiClient,
        checkInRepository: checkInRepository,
      ),
      GoalTimelineProvider(
        apiClient: apiClient,
        checkInRepository: goalCheckInRepository,
      ),
    ],
  );
}

/// Expands tasks from [RecordBloc] into timeline items.
class TaskTimelineProvider extends TimelineContentProvider {
  TaskTimelineProvider({
    ApiClientService? apiClient,
    OfflineTaskContext? offlineContext,
    TaskListBuilder? builder,
  }) : _builder = builder ??
            TaskListBuilder(
              apiClient ?? CompanionAnvilApp.instance.apiClient,
              offlineContext: offlineContext,
            );

  static const tasksQuery = RecordQuery(recordType: 'tasks', limit: 50);

  final TaskListBuilder _builder;

  @override
  List<RecordQuery> get prefetchQueries => const [tasksQuery];

  @override
  RecordQuery? get watchQuery => tasksQuery;

  @override
  Future<List<TimelineSortableItem>> load(
    RecordState state,
    TaskListHorizon horizon,
  ) async {
    final tasks = await resolveTasks(state);
    final entries = await _builder.build(tasks, horizon: horizon);
    return entries.map(TaskTimelineItem.new).toList();
  }

  List<Task> tasksFromState(RecordState state) {
    final cached = state.snapshot.queries[tasksQuery.queryKey];
    if (cached == null) return const [];

    return cached.recordIds
        .map((id) => state.snapshot.records[id]?.record)
        .where((record) => record != null && record.recordType == 'tasks')
        .cast<Task>()
        .toList();
  }

  Future<List<Task>> resolveTasks(RecordState state) async {
    final cached = state.snapshot.queries[tasksQuery.queryKey];
    if (cached == null) return const [];

    var tasks = tasksFromState(state);
    if (tasks.length == cached.recordIds.length) {
      return tasks;
    }

    tasks = await resolveTypedRecords<Task>(
      state: state,
      recordType: 'tasks',
      recordIds: cached.recordIds,
      cache: CompanionAnvilApp.instance.localCache,
      registry: buildCompanionRecordRegistry(),
    );
    return tasks;
  }
}

/// Stub provider for future event rows in the overview timeline.
class EventTimelineProvider extends TimelineContentProvider {
  const EventTimelineProvider();

  @override
  List<RecordQuery> get prefetchQueries => const [];

  @override
  RecordQuery? get watchQuery => null;

  @override
  Future<List<TimelineSortableItem>> load(
    RecordState state,
    TaskListHorizon horizon,
  ) async {
    return const [];
  }
}

/// Expands tracker check-in moments from the API into timeline items.
class TrackerTimelineProvider extends TimelineContentProvider {
  TrackerTimelineProvider({
    ApiClientService? apiClient,
    TrackerCheckInRepository? checkInRepository,
  }) : _checkInRepository = checkInRepository ??
            (apiClient != null
                ? HttpTrackerCheckInRepository(apiClient)
                : defaultTrackerCheckInRepository());

  static const trackersQuery = RecordQuery(recordType: 'trackers', limit: 50);

  final TrackerCheckInRepository _checkInRepository;

  @override
  List<RecordQuery> get prefetchQueries => const [trackersQuery];

  @override
  RecordQuery? get watchQuery => trackersQuery;

  @override
  Future<List<TimelineSortableItem>> load(
    RecordState state,
    TaskListHorizon horizon,
  ) async {
    final trackers = await resolveTrackers(state);
    final active = trackers.where((tracker) => trackerActiveInHorizon(tracker, horizon));

    if (active.isEmpty) return const [];

    final batches = await Future.wait(
      active.map((tracker) async {
        final checkIns = await _checkInRepository.fetchCheckIns(
          tracker.id,
          from: horizon.from,
          to: horizon.to,
        );
        return checkIns
            .map(
              (checkIn) => TrackerTimelineItem(
                tracker: tracker,
                checkIn: checkIn,
              ),
            )
            .toList();
      }),
    );
    return batches.expand((batch) => batch).toList();
  }

  List<Tracker> trackersFromState(RecordState state) {
    final cached = state.snapshot.queries[trackersQuery.queryKey];
    if (cached == null) return const [];

    return cached.recordIds
        .map((id) => state.snapshot.records[id]?.record)
        .where((record) => record != null && record.recordType == 'trackers')
        .cast<Tracker>()
        .toList();
  }

  Future<List<Tracker>> resolveTrackers(RecordState state) async {
    final cached = state.snapshot.queries[trackersQuery.queryKey];
    if (cached == null) return const [];

    var trackers = trackersFromState(state);
    if (trackers.length == cached.recordIds.length) {
      return trackers;
    }

    trackers = await resolveTypedRecords<Tracker>(
      state: state,
      recordType: 'trackers',
      recordIds: cached.recordIds,
      cache: CompanionAnvilApp.instance.localCache,
      registry: buildCompanionRecordRegistry(),
    );
    return trackers;
  }
}

/// Expands goal check-in moments from the API into timeline items.
class GoalTimelineProvider extends TimelineContentProvider {
  GoalTimelineProvider({
    ApiClientService? apiClient,
    GoalCheckInRepository? checkInRepository,
  }) : _checkInRepository = checkInRepository ??
            (apiClient != null
                ? HttpGoalCheckInRepository(apiClient)
                : defaultGoalCheckInRepository());

  static const goalsQuery = RecordQuery(recordType: 'goals', limit: 50);

  final GoalCheckInRepository _checkInRepository;

  @override
  List<RecordQuery> get prefetchQueries => const [goalsQuery];

  @override
  RecordQuery? get watchQuery => goalsQuery;

  @override
  Future<List<TimelineSortableItem>> load(
    RecordState state,
    TaskListHorizon horizon,
  ) async {
    final goals = await resolveGoals(state);
    final active = goals.where((goal) => goalActiveInHorizon(goal, horizon));

    if (active.isEmpty) return const [];

    final batches = await Future.wait(
      active.map((goal) async {
        final checkIns = await _checkInRepository.fetchCheckIns(
          goal.id,
          from: horizon.from,
          to: horizon.to,
        );
        return checkIns
            .map(
              (checkIn) => GoalTimelineItem(
                goal: goal,
                checkIn: checkIn,
              ),
            )
            .toList();
      }),
    );
    return batches.expand((batch) => batch).toList();
  }

  List<Goal> goalsFromState(RecordState state) {
    final cached = state.snapshot.queries[goalsQuery.queryKey];
    if (cached == null) return const [];

    return cached.recordIds
        .map((id) => state.snapshot.records[id]?.record)
        .where((record) => record != null && record.recordType == 'goals')
        .cast<Goal>()
        .toList();
  }

  Future<List<Goal>> resolveGoals(RecordState state) async {
    final cached = state.snapshot.queries[goalsQuery.queryKey];
    if (cached == null) return const [];

    var goals = goalsFromState(state);
    if (goals.length == cached.recordIds.length) {
      return goals;
    }

    goals = await resolveTypedRecords<Goal>(
      state: state,
      recordType: 'goals',
      recordIds: cached.recordIds,
      cache: CompanionAnvilApp.instance.localCache,
      registry: buildCompanionRecordRegistry(),
    );
    return goals;
  }
}
