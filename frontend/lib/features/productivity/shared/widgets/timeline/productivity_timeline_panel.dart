import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/shared/models/timeline_item.dart';
import 'package:frontend/features/productivity/shared/models/timeline_row.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_actions.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_display.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_filter.dart';
import 'package:frontend/features/productivity/shared/services/timeline_feed.dart';
import 'package:frontend/features/productivity/shared/services/timeline_grouper.dart';
import 'package:frontend/features/productivity/tasks/services/task_today_buckets.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';
import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/goals/services/goal_list_actions.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_check_in_dialog.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_check_in_timeline_tile.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_check_in_dialog.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_check_in_timeline_tile.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_list_tile.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_list_week_strip.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_list_week_strip_controller.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_list_calendar_header_controls.dart';
import 'package:frontend/features/productivity/shared/widgets/timeline/timeline_row_metrics.dart';
import 'package:frontend/shell/shell_app_bar_actions.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_today_buckets_row.dart';

/// Infinite-scroll productivity timeline with week strip and pluggable content.
class ProductivityTimelinePanel extends StatefulWidget {
  const ProductivityTimelinePanel({
    super.key,
    required this.feed,
    required this.backgroundIconName,
    this.showAddTaskRows = true,
    this.hideCompletedItems = true,
    this.taskActions,
    this.taskTimelineProvider,
    this.checkInRepository,
    this.goalCheckInRepository,
    this.scopeToDay,
    this.showWeekStrip = true,
    this.enablePagination = true,
  });

  final ProductivityTimelineFeed feed;
  final String backgroundIconName;
  final bool showAddTaskRows;

  /// When true, completed tasks and succeeded tracker check-ins are hidden.
  final bool hideCompletedItems;
  final TaskListTileActions? taskActions;
  final TaskTimelineProvider? taskTimelineProvider;
  final TrackerCheckInRepository? checkInRepository;
  final GoalCheckInRepository? goalCheckInRepository;

  /// When set, only items for this local calendar day are shown.
  final DateTime? scopeToDay;

  /// Whether the week strip overlay is shown above the list.
  final bool showWeekStrip;

  /// Whether scrolling near the edges loads more past/future days.
  final bool enablePagination;

  @override
  State<ProductivityTimelinePanel> createState() =>
      _ProductivityTimelinePanelState();
}

class _ProductivityTimelinePanelState extends State<ProductivityTimelinePanel> {
  static const _projectsQuery = RecordQuery(recordType: 'projects', limit: 50);
  static const _goalsQuery = RecordQuery(recordType: 'goals', limit: 50);
  static const _scrollLoadThreshold = 200.0;
  static const _listHorizontalPadding = 16.0;
  static const _listBottomPadding = 16.0;

  double _weekStripOverlayHeight = TaskListWeekStrip.collapsedHeight;

  double get _listTopPadding => widget.showWeekStrip
      ? _weekStripOverlayHeight + _listHorizontalPadding
      : _listHorizontalPadding;

  int _loadedQueryVersion = -1;
  int _expandOpGeneration = 0;
  List<TimelineSortableItem> _items = [];
  late TaskListHorizon _horizon;
  bool _expanding = false;
  bool _loadingPast = false;
  bool _loadingFuture = false;
  bool _loadMoreLocked = false;
  String? _expandError;
  bool _bootstrapScheduled = false;
  bool _refetchPending = false;
  bool _initialScrollDone = false;
  DateTime? _selectedDay;
  int _scrollToDayOpId = 0;
  final Set<String> _togglingTrackerCheckIns = {};
  final Set<String> _togglingGoalCheckIns = {};

  final ScrollController _scrollController = ScrollController();
  final PageController _weekPageController = PageController(
    initialPage: TaskListWeekStrip.defaultInitialPage,
  );
  final TaskListWeekStripController _weekStripController =
      TaskListWeekStripController();
  bool _appBarActionsSyncScheduled = false;
  final Map<String, GlobalKey> _dayHeaderKeys = {};

  late final TaskTimelineProvider _taskProvider =
      widget.taskTimelineProvider ?? _findTaskProvider();
  late final TaskListTileActions _actions = widget.taskActions ??
      TaskListActions(
        CompanionAnvilApp.instance.apiClient,
        offlineContext: CompanionAnvilApp.instance.offlineTaskContext,
      );
  late final TrackerListActions _trackerActions =
      TrackerListActions(CompanionAnvilApp.instance.apiClient);
  late final TrackerCheckInRepository _checkInRepository =
      widget.checkInRepository ?? defaultTrackerCheckInRepository();
  late final GoalCheckInRepository _goalCheckInRepository =
      widget.goalCheckInRepository ?? defaultGoalCheckInRepository();
  late final GoalListActions _goalActions =
      GoalListActions(CompanionAnvilApp.instance.apiClient);

  TaskTimelineProvider _findTaskProvider() {
    for (final provider in widget.feed.providers) {
      if (provider is TaskTimelineProvider) {
        return provider;
      }
    }
    return TaskTimelineProvider();
  }

  RecordQuery get _primaryWatchQuery =>
      widget.feed.watchQueries.firstOrNull ?? TaskTimelineProvider.tasksQuery;

  int _nextExpandOpId() => ++_expandOpGeneration;

  bool _applyExpandResult({
    required int opId,
    required VoidCallback apply,
  }) {
    if (opId != _expandOpGeneration) return false;
    apply();
    return true;
  }

  DateTime get _listToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  TaskListHorizon _initialHorizon() {
    final scoped = widget.scopeToDay;
    if (scoped != null) {
      final day = normalizeTaskListCalendarDay(scoped);
      return TaskListHorizon.forLocalDays(day, day);
    }
    return TaskListHorizon.aroundToday();
  }

  @override
  void initState() {
    super.initState();
    _horizon = _initialHorizon();
    _weekStripController.addListener(_syncAppBarActions);
    _fetchQueries();
    _prefetchParentRecords();
    _scheduleBootstrap();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAppBarActions());
  }

  @override
  void dispose() {
    if (widget.showWeekStrip) {
      ShellAppBarActions.clear();
    }
    _weekStripController.removeListener(_syncAppBarActions);
    _weekStripController.dispose();
    _scrollController.dispose();
    _weekPageController.dispose();
    super.dispose();
  }

  void _syncAppBarActions() {
    if (_appBarActionsSyncScheduled) return;
    _appBarActionsSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appBarActionsSyncScheduled = false;
      if (!mounted) return;
      _applyAppBarActions();
    });
  }

  void _applyAppBarActions() {
    if (!widget.showWeekStrip) {
      ShellAppBarActions.clear();
      return;
    }

    ShellAppBarActions.set([
      TaskListCalendarHeaderControls(
        isMonthView: _weekStripController.isMonthView,
        onViewModeChanged: (monthView) {
          if (monthView) {
            _weekStripController.showMonthView();
          } else {
            _weekStripController.showWeekView();
          }
        },
        onToday: () => _weekStripController.goToToday(),
      ),
    ]);
  }

  GlobalKey _keyForDay(DateTime day) {
    final id = normalizeTaskListCalendarDay(day).toIso8601String();
    return _dayHeaderKeys.putIfAbsent(id, GlobalKey.new);
  }

  Future<void> _ensureHorizonIncludes(DateTime day, RecordState state) async {
    final normalized = normalizeTaskListCalendarDay(day);
    var changed = false;
    while (normalized.isBefore(_horizon.localFromDay)) {
      _horizon = _horizon.extendBackward();
      changed = true;
    }
    while (normalized.isAfter(_horizon.localToDay)) {
      _horizon = _horizon.extendForward();
      changed = true;
    }
    if (changed) {
      await _expandFromBloc(state, force: true);
    }
  }

  Future<void> _scrollToDay(DateTime day, RecordState state) async {
    final normalized = normalizeTaskListCalendarDay(day);
    setState(() => _selectedDay = normalized);
    await _ensureHorizonIncludes(normalized, state);
    if (!mounted) return;
    await _scrollToDayInList(normalized);
  }

  int? _rowIndexForDay(DateTime day) {
    final normalized = normalizeTaskListCalendarDay(day);
    final rows = _rows;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is TimelineDateHeaderRow && row.day != null) {
        if (normalizeTaskListCalendarDay(row.day!) == normalized) {
          return i;
        }
      }
    }
    return null;
  }

  double _targetScrollOffsetForDayHeader(
    BuildContext headerContext,
    ScrollPosition position,
    double stripHeight,
  ) {
    final renderObject = headerContext.findRenderObject();
    if (renderObject == null) {
      return position.pixels;
    }
    final viewport = RenderAbstractViewport.of(renderObject);
    final reveal = viewport.getOffsetToReveal(renderObject, 0.0);
    return (reveal.offset - stripHeight).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  Future<void> _scrollToDayInList(DateTime day) async {
    final opId = ++_scrollToDayOpId;
    final index = _rowIndexForDay(day);
    if (index == null) {
      return;
    }

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToDayInList(day);
      });
      return;
    }

    _initialScrollDone = true;

    final rows = _rows;
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    final estimate = (_listTopPadding + timelineScrollOffsetForRowIndex(index, rows))
        .clamp(0.0, maxExtent);
    final stripHeight =
        widget.showWeekStrip ? _weekStripOverlayHeight : 0.0;
    final offsetBefore = position.pixels;

    var headerContext = _keyForDay(day).currentContext;
    if (headerContext != null) {
      final targetOffset = _targetScrollOffsetForDayHeader(
        headerContext,
        position,
        stripHeight,
      );
      if ((targetOffset - offsetBefore).abs() < 2) return;
      await position.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final scrollingUp = offsetBefore > estimate;
    var lo = scrollingUp ? 0.0 : offsetBefore;
    var hi = scrollingUp ? offsetBefore : maxExtent;
    lo = lo.clamp(0.0, maxExtent);
    hi = hi.clamp(0.0, maxExtent);

    for (var step = 0; step < 25; step++) {
      if (opId != _scrollToDayOpId || !mounted) return;

      final mid = (!scrollingUp && step == 0)
          ? estimate.clamp(lo, hi)
          : (lo + hi) / 2;
      _scrollController.jumpTo(mid);
      await WidgetsBinding.instance.endOfFrame;
      if (opId != _scrollToDayOpId || !mounted) return;

      headerContext = _keyForDay(day).currentContext;
      if (headerContext == null) {
        if (mid < estimate) {
          lo = mid;
        } else {
          hi = mid;
        }
        continue;
      }
      break;
    }

    headerContext = _keyForDay(day).currentContext;

    if (headerContext == null) return;

    final targetOffset = _targetScrollOffsetForDayHeader(
      headerContext,
      position,
      stripHeight,
    );

    if ((targetOffset - offsetBefore).abs() < 2) return;

    _scrollController.jumpTo(targetOffset);
  }

  List<TimelineRow> get _rows {
    final taskEntries = _taskEntries;
    final bucketCounts = computeTaskTodayBucketCounts(
      taskEntries,
      _listToday,
      trackerItems: _trackerItems,
      goalItems: _goalItems,
      now: DateTime.now(),
    );
    final visibleItems = filterVisibleTimelineItems(
      _items,
      hideCompleted: widget.hideCompletedItems,
      listToday: _listToday,
    );
    final sections = groupTimelineItems(visibleItems, horizon: _horizon);
    var rows = flattenTimelineRows(
      sections,
      showPastLoader: _loadingPast,
      showFutureLoader: _loadingFuture,
      showAddTaskRows: widget.showAddTaskRows,
    );
    rows = applyTodayBucketsToTimelineRows(
      rows: rows,
      today: _listToday,
      counts: bucketCounts,
    );
    return rows;
  }

  List<TaskListEntry> get _taskEntries => [
        for (final item in _items)
          if (item is TaskTimelineItem) item.entry,
      ];

  List<TrackerTimelineItem> get _trackerItems => [
        for (final item in _items)
          if (item is TrackerTimelineItem) item,
      ];

  List<GoalTimelineItem> get _goalItems => [
        for (final item in _items)
          if (item is GoalTimelineItem) item,
      ];

  Future<void> _openTodayBucket(TaskTodayBucket bucket) async {
    final referenceNow = DateTime.now();
    await CompanionNavigation.openTaskTodayBucket(
      context,
      bucket: bucket,
      listToday: _listToday,
      entries: taskEntriesForTodayBucket(_taskEntries, bucket, _listToday),
      trackerItems: trackerItemsForTodayBucket(
        _trackerItems,
        bucket,
        _listToday,
        now: referenceNow,
      ),
      taskActions: _actions,
      trackerActions: _trackerItems.isEmpty ? null : _trackerActions,
      checkInRepository: _checkInRepository,
      onTrackerListChanged: refreshList,
    );
    if (!mounted) return;
    await refreshList();
  }

  void _prefetchParentRecords() {
    final bloc = context.read<RecordBloc>();
    final snapshot = bloc.state.snapshot;
    if (snapshot.queries[_projectsQuery.queryKey] == null) {
      bloc.add(const QueryRecordsRequested(_projectsQuery));
    }
    if (snapshot.queries[_goalsQuery.queryKey] == null) {
      bloc.add(const QueryRecordsRequested(_goalsQuery));
    }
  }

  Project? _linkedProject(Task task, RecordState state) {
    final id = task.projectId;
    if (id == null || id.isEmpty) return null;
    final record = state.snapshot.records[id]?.record;
    return record is Project ? record : null;
  }

  Goal? _linkedGoal(Task task, RecordState state) {
    final id = task.goalId;
    if (id == null || id.isEmpty) return null;
    final record = state.snapshot.records[id]?.record;
    return record is Goal ? record : null;
  }

  void _scheduleBootstrap() {
    if (_bootstrapScheduled) return;
    _bootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapScheduled = false;
      if (!mounted) return;
      _bootstrapFromBloc(context.read<RecordBloc>().state);
    });
  }

  void _bootstrapFromBloc(RecordState state) {
    final cached = state.snapshot.queries[_primaryWatchQuery.queryKey];
    if (cached == null) {
      _fetchQueries();
      return;
    }

    if (_loadedQueryVersion >= cached.version &&
        (_items.isNotEmpty || cached.recordIds.isEmpty)) {
      return;
    }

    _expandFromBloc(state);
  }

  void _fetchQueries() {
    final bloc = context.read<RecordBloc>();
    for (final query in widget.feed.prefetchQueries) {
      bloc.add(QueryRecordsRequested(query));
    }
  }

  Future<void> refreshList() async {
    if (!mounted) return;
    setState(() {
      _expandError = null;
      _expanding = true;
      _horizon = _initialHorizon();
      _initialScrollDone = widget.scopeToDay != null;
      _selectedDay = widget.scopeToDay ?? _listToday;
    });
    final bloc = context.read<RecordBloc>();
    final key = _primaryWatchQuery.queryKey;
    final versionBefore = bloc.state.snapshot.queries[key]?.version ?? -1;
    for (final query in widget.feed.prefetchQueries) {
      bloc.remoteCoordinator?.refreshQueryRecords(query);
    }
    await bloc.stream
        .firstWhere(
          (snapshot) {
            final cached = snapshot.snapshot.queries[key];
            return cached != null &&
                cached.freshness == RecordFreshness.fresh &&
                cached.version > versionBefore;
          },
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => bloc.state,
        );
    if (mounted) await _expandFromBloc(bloc.state, force: true);
  }

  Future<void> _expandFromBloc(RecordState state, {bool force = false}) async {
    final cached = state.snapshot.queries[_primaryWatchQuery.queryKey];
    if (cached == null) return;
    if (!force && (_loadMoreLocked || _loadingPast || _loadingFuture)) {
      return;
    }
    if (!force &&
        cached.version <= _loadedQueryVersion &&
        _items.isNotEmpty) {
      return;
    }
    if (!force && _expanding) {
      return;
    }

    var tasks = _taskProvider.tasksFromState(state);
    if (tasks.length != cached.recordIds.length) {
      tasks = await _taskProvider.resolveTasks(state);
    }

    if (tasks.length != cached.recordIds.length) {
      if (!_refetchPending) {
        _refetchPending = true;
        final versionBefore = cached.version;
        context.read<RecordBloc>().remoteCoordinator?.refreshQueryRecords(
              TaskTimelineProvider.tasksQuery,
            );
        try {
          await context.read<RecordBloc>().stream
              .firstWhere(
                (snapshot) =>
                    (snapshot.snapshot.queries[TaskTimelineProvider
                                .tasksQuery
                                .queryKey]
                            ?.version ??
                        -1) >
                    versionBefore,
              )
              .timeout(const Duration(seconds: 30));
        } catch (_) {}
        _refetchPending = false;
        if (mounted) {
          await _expandFromBloc(
            context.read<RecordBloc>().state,
            force: force,
          );
        }
      }
      if (tasks.isEmpty) {
        return;
      }
    }

    _refetchPending = false;

    setState(() {
      _expanding = true;
      _expandError = null;
    });

    final opId = _nextExpandOpId();

    try {
      final items = await widget.feed.load(state, _horizon);
      if (!mounted) return;
      _applyExpandResult(
        opId: opId,
        apply: () {
          setState(() {
            _items = items;
            _loadedQueryVersion = cached.version;
            _expanding = false;
          });
          _scrollToTodayIfNeeded();
        },
      );
    } catch (error) {
      if (!mounted) return;
      if (opId == _expandOpGeneration) {
        setState(() {
          _expanding = false;
          _expandError = error.toString();
        });
      }
    }
  }

  Future<void> _loadMorePast(RecordState state) async {
    if (_loadingPast || _loadingFuture || _loadMoreLocked) return;

    final oldMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    setState(() {
      _loadingPast = true;
      _loadMoreLocked = true;
    });

    _horizon = _horizon.extendBackward();
    final horizon = _horizon;
    final opId = _nextExpandOpId();

    try {
      final items = await widget.feed.load(state, horizon);
      if (!mounted) return;
      final applied = _applyExpandResult(
        opId: opId,
        apply: () {
          setState(() {
            _items = items;
            _loadingPast = false;
            _loadMoreLocked = false;
          });
        },
      );
      if (!applied && mounted) {
        setState(() {
          _loadingPast = false;
          _loadMoreLocked = false;
        });
        return;
      }
      if (!applied) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients || !mounted) return;
        final newMax = _scrollController.position.maxScrollExtent;
        final delta = newMax - oldMax;
        final targetOffset = oldOffset + delta;
        if (delta > 0) {
          _scrollController.jumpTo(targetOffset);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPast = false;
        _loadMoreLocked = false;
        _expandError = error.toString();
      });
    }
  }

  Future<void> _loadMoreFuture(RecordState state) async {
    if (_loadingPast || _loadingFuture || _loadMoreLocked) return;

    setState(() {
      _loadingFuture = true;
      _loadMoreLocked = true;
    });

    _horizon = _horizon.extendForward();
    final horizon = _horizon;
    final opId = _nextExpandOpId();

    try {
      final items = await widget.feed.load(state, horizon);
      if (!mounted) return;
      final applied = _applyExpandResult(
        opId: opId,
        apply: () {
          setState(() {
            _items = items;
            _loadingFuture = false;
            _loadMoreLocked = false;
          });
        },
      );
      if (!applied && mounted) {
        setState(() {
          _loadingFuture = false;
          _loadMoreLocked = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingFuture = false;
        _loadMoreLocked = false;
        _expandError = error.toString();
      });
    }
  }

  bool _handleScrollNotification(
    ScrollNotification notification,
    RecordState state,
  ) {
    if (!widget.enablePagination) return false;
    if (!_scrollController.hasClients || _loadMoreLocked) return false;
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.pixels <= _scrollLoadThreshold) {
      _loadMorePast(state);
    } else if (metrics.pixels >=
        metrics.maxScrollExtent - _scrollLoadThreshold) {
      _loadMoreFuture(state);
    }
    return false;
  }

  void _scrollToTodayIfNeeded() {
    if (widget.scopeToDay != null || _initialScrollDone) return;
    setState(() => _selectedDay ??= _listToday);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialScrollDone) return;
      _initialScrollDone = true;
      _scrollToDayInList(_listToday);
    });
  }

  void _updateEntry(TaskListEntry updated) {
    final index = _items.indexWhere(
      (item) => item is TaskTimelineItem && item.entry.listKey == updated.listKey,
    );
    if (index < 0) return;
    setState(() {
      _items[index] = TaskTimelineItem(applyTaskListDisplayRules(updated));
    });
  }

  Future<void> _openCreate() async {
    await CompanionNavigation.openTaskCreate(context);
    await refreshList();
  }

  void _openEdit(Task task) {
    CompanionNavigation.openTaskEdit(context, taskId: task.id)
        .then((_) => refreshList());
  }

  void _openTrackerEdit(Tracker tracker) {
    CompanionNavigation.openTrackerEdit(
      context,
      trackerId: tracker.id,
      tracker: tracker,
    ).then((_) => refreshList());
  }

  void _openGoalDetail(Goal goal) {
    CompanionNavigation.openGoalDetail(
      context,
      goalId: goal.id,
      goal: goal,
    ).then((_) => refreshList());
  }

  void _openGoalEdit(Goal goal) {
    CompanionNavigation.openGoalEdit(
      context,
      goalId: goal.id,
      goal: goal,
    ).then((_) => refreshList());
  }

  Future<void> _openGoalCheckIn(
    Goal goal,
    GoalCheckIn checkIn,
  ) async {
    final saved = await showGoalCheckInDialog(
      context: context,
      goal: goal,
      repository: _goalCheckInRepository,
      checkIn: checkIn,
      checkInAt: checkIn.checkInAt,
    );
    if (saved == true && mounted) {
      await refreshList();
    }
  }

  String _goalCheckInToggleKey(Goal goal, GoalCheckIn checkIn) =>
      '${goal.id}:${checkIn.id}';

  Future<void> _toggleGoalCheckIn(
    Goal goal,
    GoalCheckIn checkIn,
  ) async {
    if (goal.goalType != GoalType.task) return;

    final key = _goalCheckInToggleKey(goal, checkIn);
    if (_togglingGoalCheckIns.contains(key)) return;

    setState(() => _togglingGoalCheckIns.add(key));
    try {
      await toggleTaskGoalCheckIn(
        _goalCheckInRepository,
        goal,
        checkIn,
      );
      if (mounted) await refreshList();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingGoalCheckIns.remove(key));
      }
    }
  }

  VoidCallback? _goalOutcomePressed(Goal goal, GoalCheckIn checkIn) {
    return switch (goal.goalType) {
      GoalType.task => () => _toggleGoalCheckIn(goal, checkIn),
      GoalType.count => () => _openGoalCheckIn(goal, checkIn),
      GoalType.pulse => null,
      _ => null,
    };
  }

  void _openTrackerDetail(Tracker tracker) {
    CompanionNavigation.openTrackerDetail(
      context,
      trackerId: tracker.id,
      tracker: tracker,
    ).then((_) => refreshList());
  }

  Future<void> _openTrackerCheckIn(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    final saved = await showTrackerCheckInDialog(
      context: context,
      tracker: tracker,
      repository: _checkInRepository,
      checkIn: checkIn,
      checkInAt: checkIn.checkInAt,
    );
    if (saved == true && mounted) {
      await refreshList();
    }
  }

  String _trackerCheckInToggleKey(Tracker tracker, TrackerCheckIn checkIn) =>
      '${tracker.id}:${checkIn.id}';

  Future<void> _toggleTrackerCheckIn(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    if (tracker.checkInType != TrackerCheckInType.task) return;

    final key = _trackerCheckInToggleKey(tracker, checkIn);
    if (_togglingTrackerCheckIns.contains(key)) return;

    setState(() => _togglingTrackerCheckIns.add(key));
    try {
      await toggleTaskTrackerCheckIn(
        _checkInRepository,
        tracker,
        checkIn,
      );
      if (mounted) {
        await refreshList();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTrackerCheckIns.remove(key));
      }
    }
  }

  Future<void> _incrementTrackerCheckIn(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    if (tracker.checkInType != TrackerCheckInType.count) return;

    final key = _trackerCheckInToggleKey(tracker, checkIn);
    if (_togglingTrackerCheckIns.contains(key)) return;

    setState(() => _togglingTrackerCheckIns.add(key));
    try {
      await incrementCountTrackerCheckIn(
        _checkInRepository,
        tracker,
        checkIn,
      );
      if (mounted) {
        await refreshList();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTrackerCheckIns.remove(key));
      }
    }
  }

  Future<void> _toggleDurationTrackerTimer(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    if (tracker.checkInType != TrackerCheckInType.duration) return;

    final key = _trackerCheckInToggleKey(tracker, checkIn);
    if (_togglingTrackerCheckIns.contains(key)) return;

    setState(() => _togglingTrackerCheckIns.add(key));
    try {
      if (checkIn.timerStartedAt != null) {
        await stopDurationTrackerTimer(
          _checkInRepository,
          tracker,
          checkIn,
        );
      } else {
        await startDurationTrackerTimer(
          _checkInRepository,
          tracker,
          checkIn,
        );
      }
      if (mounted) {
        await refreshList();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTrackerCheckIns.remove(key));
      }
    }
  }

  VoidCallback? _trackerOutcomePressed(Tracker tracker, TrackerCheckIn checkIn) {
    return switch (tracker.checkInType) {
      TrackerCheckInType.task => () => _toggleTrackerCheckIn(tracker, checkIn),
      TrackerCheckInType.count =>
        () => _incrementTrackerCheckIn(tracker, checkIn),
      TrackerCheckInType.duration =>
        () => _toggleDurationTrackerTimer(tracker, checkIn),
      _ => null,
    };
  }

  Widget _buildRow(TimelineRow row, RecordState state, {required bool compact}) {
    final hideLeadingIcon = compact;
    return switch (row) {
      TimelineDateHeaderRow(:final day) => TaskListDateHeader(
          key: day == null ? null : ValueKey('day-${day.toIso8601String()}'),
          day: day,
          listToday: _listToday,
          headerKey: day != null ? _keyForDay(day) : null,
        ),
      TimelineTodayBucketsRow(:final counts) => TaskTodayBucketsRow(
          counts: counts,
          onBucketTap: _openTodayBucket,
          compact: compact,
        ),
      TimelineTaskEntryRow(
        :final entry,
        :final isFirstInDay,
      ) =>
        TaskListTile(
          key: ValueKey(entry.listKey),
          entry: entry,
          actions: _actions,
          linkedProject: _linkedProject(entry.task, state),
          linkedGoal: _linkedGoal(entry.task, state),
          isFirst: isFirstInDay,
          isLast: false,
          hideLeadingIcon: hideLeadingIcon,
          onEdit: () => _openEdit(entry.task),
          onChanged: _updateEntry,
          onDeleted: refreshList,
        ),
      TimelineEventEntryRow() => const SizedBox.shrink(),
      TimelineTrackerCheckInRow(
        :final tracker,
        :final checkIn,
        :final isFirstInDay,
      ) =>
        TrackerCheckInTimelineTile(
          key: ValueKey('tracker:${tracker.id}:${checkIn.id}'),
          tracker: tracker,
          checkIn: checkIn,
          actions: _trackerActions,
          isFirst: isFirstInDay,
          isLast: false,
          hideLeadingIcon: hideLeadingIcon,
          onTap: () => _openTrackerDetail(tracker),
          onLongPress: () => _openTrackerEdit(tracker),
          onEdit: () => _openTrackerEdit(tracker),
          onDeleted: refreshList,
          onOutcomePressed: _trackerOutcomePressed(tracker, checkIn),
          onOutcomeLongPress: () => _openTrackerCheckIn(tracker, checkIn),
          outcomeToggleEnabled: !_togglingTrackerCheckIns.contains(
            _trackerCheckInToggleKey(tracker, checkIn),
          ),
        ),
      TimelineGoalCheckInRow(
        :final goal,
        :final checkIn,
        :final isFirstInDay,
      ) =>
        GoalCheckInTimelineTile(
          key: ValueKey('goal:${goal.id}:${checkIn.id}'),
          goal: goal,
          checkIn: checkIn,
          actions: _goalActions,
          isFirst: isFirstInDay,
          isLast: false,
          hideLeadingIcon: hideLeadingIcon,
          onTap: () => _openGoalDetail(goal),
          onLongPress: () => _openGoalCheckIn(goal, checkIn),
          onEdit: () => _openGoalEdit(goal),
          onDeleted: refreshList,
          onOutcomePressed: _goalOutcomePressed(goal, checkIn),
          onOutcomeLongPress: () => _openGoalCheckIn(goal, checkIn),
          outcomeToggleEnabled: !_togglingGoalCheckIns.contains(
            _goalCheckInToggleKey(goal, checkIn),
          ),
        ),
      TimelineLoadingRow() => const TaskListLoadingTile(),
      TimelineAddTaskRow(:final hasTasksAbove) => TaskListAddTile(
          hasTasksAbove: hasTasksAbove,
          onPressed: _openCreate,
        ),
    };
  }

  bool _watchQueryChanged(RecordState previous, RecordState current) {
    for (final query in widget.feed.watchQueries) {
      final key = query.queryKey;
      final prevVersion = previous.snapshot.queries[key]?.version ?? -1;
      final currVersion = current.snapshot.queries[key]?.version ?? -1;
      if (currVersion > prevVersion) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final iconData =
        IconRegistry.instance.getIconData(widget.backgroundIconName) ??
            Icons.view_timeline_outlined;

    return AnvilBackgroundIcon(
      icon: iconData,
      child: BlocConsumer<RecordBloc, RecordState>(
        listenWhen: _watchQueryChanged,
        listener: (context, state) {
          if (_loadMoreLocked || _loadingPast || _loadingFuture) {
            return;
          }
          _expandFromBloc(state);
        },
        builder: (context, state) {
          final key = _primaryWatchQuery.queryKey;
          final queryError = state.snapshot.errors
              .where((error) => error.key == key)
              .map((error) => error.message)
              .firstOrNull;
          final cached = state.snapshot.queries[key];

          final waitingForCapture = cached != null &&
              cached.recordIds.isNotEmpty &&
              _items.isEmpty &&
              _loadedQueryVersion < cached.version;

          if (waitingForCapture) {
            _scheduleBootstrap();
          }

          if (queryError != null &&
              (cached == null || cached.freshness != RecordFreshness.fresh)) {
            return AnvilErrorState(
              message: queryError,
              onRetry: _fetchQueries,
            );
          }

          if (cached == null ||
              waitingForCapture ||
              (_expanding && _items.isEmpty)) {
            return _loadingSkeleton();
          }

          if (_expandError != null) {
            return AnvilErrorState(
              message: _expandError!,
              onRetry: () => _expandFromBloc(state, force: true),
            );
          }

          final rows = _rows;
          final stripHeight =
              widget.showWeekStrip ? _weekStripOverlayHeight : 0.0;
          final listTopPadding = _listTopPadding;
          final compact = CompanionLayout.isCompact(context);

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: RefreshIndicator(
                  onRefresh: refreshList,
                  edgeOffset: stripHeight,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) =>
                        _handleScrollNotification(notification, state),
                    child: ListView.builder(
                      controller: _scrollController,
                      clipBehavior:
                          compact ? Clip.none : Clip.hardEdge,
                      padding: CompanionFormStyles.taskListPagePadding(
                        top: listTopPadding,
                        bottom: _listBottomPadding,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (context, index) =>
                          _buildRow(rows[index], state, compact: compact),
                    ),
                  ),
                ),
              ),
              if (widget.showWeekStrip)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TaskListWeekStrip(
                    listToday: _listToday,
                    selectedDay: _selectedDay,
                    controller: _weekStripController,
                    pageController: _weekPageController,
                    onOverlayHeightChanged: (height) {
                      if ((height - _weekStripOverlayHeight).abs() < 0.5) {
                        return;
                      }
                      setState(() => _weekStripOverlayHeight = height);
                    },
                    onDaySelected: (day) => _scrollToDay(day, state),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _loadingSkeleton() {
    return ListView(
      padding: CompanionFormStyles.taskListPagePadding(top: 16),
      children: List.generate(
        5,
        (_) => Padding(
          padding: const EdgeInsets.only(
            bottom: CompanionFormStyles.taskRowVerticalGap,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: CompanionFormStyles.taskTimelineWidth,
                child: Center(
                  child: AnvilSkeletonLoader.circle(
                    size: CompanionFormStyles.taskTimelineNodeSize,
                  ),
                ),
              ),
              const Expanded(
                child: AnvilSkeletonLoader(height: 76),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
