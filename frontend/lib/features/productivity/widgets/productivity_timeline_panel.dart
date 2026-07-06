import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/models/timeline_row.dart';
import 'package:frontend/features/productivity/pages/task_bucket_list_page.dart';
import 'package:frontend/features/productivity/pages/task_create_page.dart';
import 'package:frontend/features/productivity/pages/task_edit_page.dart';
import 'package:frontend/features/productivity/pages/tracker_detail_page.dart';
import 'package:frontend/features/productivity/pages/tracker_edit_page.dart';
import 'package:frontend/features/productivity/services/task_bucket_summary.dart';
import 'package:frontend/features/productivity/services/task_list_actions.dart';
import 'package:frontend/features/productivity/services/task_list_builder.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';
import 'package:frontend/features/productivity/services/timeline_feed.dart';
import 'package:frontend/features/productivity/services/timeline_grouper.dart';
import 'package:frontend/features/productivity/widgets/task_bucket_row.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';
import 'package:frontend/features/productivity/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/widgets/tracker_check_in_dialog.dart';
import 'package:frontend/features/productivity/widgets/tracker_check_in_timeline_tile.dart';
import 'package:frontend/features/productivity/widgets/task_list_tile.dart';
import 'package:frontend/features/productivity/widgets/task_list_week_strip.dart';

/// Infinite-scroll productivity timeline with week strip and pluggable content.
class ProductivityTimelinePanel extends StatefulWidget {
  const ProductivityTimelinePanel({
    super.key,
    required this.feed,
    required this.backgroundIconName,
    this.showAddTaskRows = true,
    this.showTaskBuckets,
    this.taskActions,
    this.taskTimelineProvider,
    this.checkInRepository,
  });

  final ProductivityTimelineFeed feed;
  final String backgroundIconName;
  final bool showAddTaskRows;
  final bool? showTaskBuckets;
  final TaskListTileActions? taskActions;
  final TaskTimelineProvider? taskTimelineProvider;
  final TrackerCheckInRepository? checkInRepository;

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

  double get _listTopPadding =>
      _weekStripOverlayHeight + _listHorizontalPadding;

  int _loadedQueryVersion = -1;
  int _expandOpGeneration = 0;
  List<TimelineSortableItem> _items = [];
  TaskListHorizon _horizon = TaskListHorizon.aroundToday();
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
  TaskBucketSummary? _taskBucketSummary;

  final ScrollController _scrollController = ScrollController();
  final PageController _weekPageController = PageController(
    initialPage: TaskListWeekStrip.defaultInitialPage,
  );
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

  bool get _showTaskBuckets =>
      widget.showTaskBuckets ??
      widget.feed.providers.any((provider) => provider is TaskTimelineProvider);

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

  @override
  void initState() {
    super.initState();
    _fetchQueries();
    _prefetchParentRecords();
    _scheduleBootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _weekPageController.dispose();
    super.dispose();
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

  double _rowScrollExtent(TimelineRow row) {
    return switch (row) {
      TimelineDateHeaderRow() =>
        CompanionFormStyles.sectionHeaderMarginTop +
            CompanionFormStyles.sectionHeaderMarginBottom +
            24,
      TimelineTaskBucketRow() =>
        24 + 12 + 72 + CompanionFormStyles.taskRowVerticalGap,
      TimelineAddTaskRow() =>
        CompanionFormStyles.taskTimelineNodeOuterSize +
            CompanionFormStyles.taskRowVerticalGap,
      TimelineTaskEntryRow(:final entry) =>
        112 +
            entry.subtasks.length * 40 +
            CompanionFormStyles.taskRowVerticalGap,
      TimelineEventEntryRow() => 112 + CompanionFormStyles.taskRowVerticalGap,
      TimelineTrackerCheckInRow() =>
        112 + CompanionFormStyles.taskRowVerticalGap,
      TimelineLoadingRow() => 56,
    };
  }

  double _scrollOffsetForRowIndex(int index, List<TimelineRow> rows) {
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += _rowScrollExtent(rows[i]);
    }
    return offset;
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
    final estimate = (_listTopPadding + _scrollOffsetForRowIndex(index, rows))
        .clamp(0.0, maxExtent);
    final stripHeight = _weekStripOverlayHeight;
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

    var lo = (offsetBefore < estimate ? offsetBefore : estimate) - 200;
    var hi = (offsetBefore > estimate ? offsetBefore : estimate) + 200;
    lo = lo.clamp(0.0, maxExtent);
    hi = hi.clamp(0.0, maxExtent);

    for (var step = 0; step < 20; step++) {
      if (opId != _scrollToDayOpId || !mounted) return;

      final mid = step == 0 ? estimate.clamp(lo, hi) : (lo + hi) / 2;
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
    final sections = groupTimelineItems(_items, horizon: _horizon);
    return flattenTimelineRows(
      sections,
      showPastLoader: _loadingPast,
      showFutureLoader: _loadingFuture,
      showAddTaskRows: widget.showAddTaskRows,
      taskBucketSummary:
          _showTaskBuckets ? (_taskBucketSummary ?? TaskBucketSummary.empty) : null,
      today: _listToday,
    );
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
      _horizon = TaskListHorizon.aroundToday();
      _initialScrollDone = false;
      _selectedDay = _listToday;
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
      TaskBucketSummary? bucketSummary;
      if (_showTaskBuckets) {
        bucketSummary = await _taskProvider.computeBucketSummary(tasks);
      }
      if (!mounted) return;
      _applyExpandResult(
        opId: opId,
        apply: () {
          setState(() {
            _items = items;
            _taskBucketSummary = bucketSummary;
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
    if (_initialScrollDone) return;
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TaskCreatePage(),
      ),
    );
    await refreshList();
  }

  void _openEdit(Task task) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TaskEditPage(taskId: task.id),
          ),
        )
        .then((_) => refreshList());
  }

  void _openTaskBucket(TaskBucket bucket) {
    final summary = _taskBucketSummary ?? TaskBucketSummary.empty;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TaskBucketListPage(
              bucket: bucket,
              entries: summary.entriesForBucket(bucket),
              actions: _actions,
              onEntryChanged: _updateEntry,
              onDeleted: refreshList,
            ),
          ),
        )
        .then((_) => refreshList());
  }

  void _openTrackerEdit(Tracker tracker) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TrackerEditPage(
              trackerId: tracker.id,
              tracker: tracker,
            ),
          ),
        )
        .then((_) => refreshList());
  }

  void _openTrackerDetail(Tracker tracker) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TrackerDetailPage(
              trackerId: tracker.id,
              tracker: tracker,
              trackerActions: _trackerActions,
              checkInRepository: _checkInRepository,
            ),
          ),
        )
        .then((_) => refreshList());
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

  Widget _buildRow(TimelineRow row, RecordState state) {
    return switch (row) {
      TimelineDateHeaderRow(:final day) => TaskListDateHeader(
          key: day == null ? null : ValueKey('day-${day.toIso8601String()}'),
          day: day,
          listToday: _listToday,
          headerKey: day != null ? _keyForDay(day) : null,
        ),
      TimelineTaskBucketRow(:final summary) => TaskBucketRow(
          summary: summary,
          onBucketTap: _openTaskBucket,
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
          final stripHeight = _weekStripOverlayHeight;
          final listTopPadding = _listTopPadding;

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
                      clipBehavior: Clip.hardEdge,
                      padding: EdgeInsets.fromLTRB(
                        _listHorizontalPadding,
                        listTopPadding,
                        _listHorizontalPadding,
                        _listBottomPadding,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (context, index) =>
                          _buildRow(rows[index], state),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TaskListWeekStrip(
                  listToday: _listToday,
                  selectedDay: _selectedDay,
                  pageController: _weekPageController,
                  onOverlayHeightChanged: (height) {
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
      padding: const EdgeInsets.all(16),
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
