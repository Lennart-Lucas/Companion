import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/shared/models/timeline_item.dart';
import 'package:frontend/features/productivity/shared/models/timeline_row.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_actions.dart';
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
import 'package:frontend/features/productivity/shared/services/weekly_summary_timeline.dart';
import 'package:frontend/features/productivity/shared/widgets/timeline/weekly_summary_timeline_tile.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_today_buckets_row.dart';

part 'timeline_panel_scroll.dart';
part 'timeline_panel_data.dart';
part 'timeline_panel_check_ins.dart';
part 'timeline_panel_rows.dart';

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
    this.showWeeklySummaries = false,
  });

  final ProductivityTimelineFeed feed;
  final String backgroundIconName;
  final bool showAddTaskRows;
  final bool hideCompletedItems;
  final TaskListTileActions? taskActions;
  final TaskTimelineProvider? taskTimelineProvider;
  final TrackerCheckInRepository? checkInRepository;
  final GoalCheckInRepository? goalCheckInRepository;
  final DateTime? scopeToDay;
  final bool showWeekStrip;
  final bool enablePagination;
  final bool showWeeklySummaries;

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
    if (widget.showWeeklySummaries) {
      rows = applyWeeklySummaryRows(
        rows: rows,
        today: _listToday,
        horizon: _horizon,
        previewForWeek: (weekStart) => computeWeeklySummaryPreview(
          weekStart: weekStart,
          taskEntries: _taskEntries,
          trackerItems: _trackerItems,
          goalItems: _goalItems,
        ),
      );
    }
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

  void _openTrackerDetail(Tracker tracker) {
    CompanionNavigation.openTrackerDetail(
      context,
      trackerId: tracker.id,
      tracker: tracker,
    ).then((_) => refreshList());
  }

  void _openWeeklySummary(DateTime weekStart) {
    CompanionNavigation.openWeeklySummary(
      context,
      weekStart: weekStart,
    ).then((_) => refreshList());
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
