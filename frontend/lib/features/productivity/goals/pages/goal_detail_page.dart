import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';

import 'package:frontend/features/productivity/goals/pages/goal_edit_page.dart';
import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/goals/services/goal_list_actions.dart';
import 'package:frontend/features/productivity/goals/services/goal_stats.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_check_in_dialog.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_detail_sidebar.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_display.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_stats_section.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';

class GoalDetailPage extends StatefulWidget {
  const GoalDetailPage({
    super.key,
    required this.goalId,
    this.goal,
    this.goalActions,
    this.checkInRepository,
    this.initialCheckIns,
    this.listToday,
  });

  final RecordId goalId;
  final Goal? goal;
  final GoalListTileActions? goalActions;
  final GoalCheckInRepository? checkInRepository;
  final List<GoalCheckIn>? initialCheckIns;
  final DateTime? listToday;

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  static const _goalsQuery = RecordQuery(recordType: 'goals', limit: 50);

  bool _deleting = false;
  bool _loadingCheckIns = false;
  String? _checkInError;
  List<GoalCheckIn> _checkIns = [];
  late DateTime _displayedMonth;
  late DateTime _listToday;
  Goal? _cachedGoal;
  bool _goalHydrationRequested = false;
  bool _cacheBootstrapScheduled = false;

  GoalListTileActions get _actions =>
      widget.goalActions ??
      GoalListActions(CompanionAnvilApp.instance.apiClient);

  GoalCheckInRepository get _checkInRepository =>
      widget.checkInRepository ?? defaultGoalCheckInRepository();

  @override
  void initState() {
    super.initState();
    _listToday = normalizeTaskListCalendarDay(
      widget.listToday ?? DateTime.now(),
    );
    _displayedMonth = taskListMonthStart(_listToday);
    _checkIns = widget.initialCheckIns ?? [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchGoal();
      _ensureGoalHydrated();
      _scheduleCacheBootstrap();
      if (widget.initialCheckIns == null) {
        _loadCheckIns();
      }
    });
  }

  void _scheduleCacheBootstrap() {
    if (_cacheBootstrapScheduled) return;
    _cacheBootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _cacheBootstrapScheduled = false;
      if (!mounted) return;
      await _bootstrapGoalFromCache();
    });
  }

  Future<void> _bootstrapGoalFromCache() async {
    if (_goal(context.read<RecordBloc>().state) != null) return;

    LocalRecordCacheService cache;
    try {
      cache = CompanionAnvilApp.instance.localCache;
    } on StateError {
      return;
    }

    final json = await cache.loadRecord(
      'goals',
      widget.goalId,
    );
    if (json == null || !mounted) return;

    final goal = buildCompanionRecordRegistry()
        .getConfig('goals')
        .fromJson(json) as Goal;
    setState(() => _cachedGoal = goal);
    if (widget.initialCheckIns == null) {
      await _loadCheckIns();
    }
  }

  void _ensureGoalHydrated() {
    if (_goalHydrationRequested) return;
    if (_goal(context.read<RecordBloc>().state) != null) return;

    _goalHydrationRequested = true;
    context.read<RecordBloc>().add(
          GetRecordRequested(
            recordType: 'goals',
            recordId: widget.goalId,
          ),
        );
  }

  void _prefetchGoal() {
    final bloc = context.read<RecordBloc>();
    if (bloc.state.snapshot.queries[_goalsQuery.queryKey] == null) {
      bloc.add(const QueryRecordsRequested(_goalsQuery));
    }
  }

  Goal? _goal(RecordState state) {
    final record = state.snapshot.records[widget.goalId]?.record;
    if (record is Goal) return record;
    return widget.goal ?? _cachedGoal;
  }

  Future<void> _loadCheckIns() async {
    final goal = _goal(context.read<RecordBloc>().state);
    if (goal == null) return;

    setState(() {
      _loadingCheckIns = true;
      _checkInError = null;
    });

    try {
      final checkIns = await _checkInRepository.fetchGoalHistory(goal);
      if (!mounted) return;
      setState(() {
        _checkIns = checkIns;
        _loadingCheckIns = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCheckIns = false;
        _checkInError = error.toString();
      });
    }
  }

  void _refreshRecords() {
    context.read<RecordBloc>().remoteCoordinator?.refreshQueryRecords(
          _goalsQuery,
        );
  }

  Future<void> _onRefresh() async {
    _refreshRecords();
    final bloc = context.read<RecordBloc>();
    final key = _goalsQuery.queryKey;
    final versionBefore = bloc.state.snapshot.queries[key]?.version ?? -1;
    try {
      await bloc.stream
          .firstWhere(
            (s) => (s.snapshot.queries[key]?.version ?? -1) > versionBefore,
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {}
    await _loadCheckIns();
  }

  void _openEdit(Goal goal) {
    if (_deleting) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => GoalEditPage(
              goalId: goal.id,
              goal: goal,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          context.read<RecordBloc>().add(
                GetRecordRequested(
                  recordType: 'goals',
                  recordId: widget.goalId,
                ),
              );
          _refreshRecords();
        });
  }

  Future<void> _confirmAndDeleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete goal?'),
        content: const Text(
          'This goal and its check-in history will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      await _actions.deleteGoal(goal.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
      );
    });
  }

  void _showNextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
      );
    });
  }

  void _goToCurrentMonth() {
    setState(() {
      _displayedMonth = taskListMonthStart(_listToday);
    });
  }

  DateTime _defaultCheckInAtForDay(DateTime day) {
    final normalized = normalizeTaskListCalendarDay(day);
    final today = normalizeTaskListCalendarDay(_listToday);
    if (normalized == today) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, now.hour, now.minute);
    }
    return DateTime(normalized.year, normalized.month, normalized.day, 12);
  }

  Future<void> _onCalendarDaySelected(Goal goal, DateTime day) async {
    try {
      var moments = goalCheckInsOnDay(_checkIns, day);
      if (moments.isEmpty) {
        try {
          moments = await _checkInRepository
              .fetchCheckInsForDay(goal.id, day)
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          moments = const [];
        }
      }
      if (!mounted) return;

      GoalCheckIn? selected;
      if (moments.length > 1) {
        selected = await showDialog<GoalCheckIn>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Choose check-in'),
            children: [
              for (final moment in moments)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, moment),
                  child: Text(moment.checkInAt.toLocal().toString()),
                ),
            ],
          ),
        );
        if (selected == null || !mounted) return;
      } else if (moments.length == 1) {
        selected = moments.first;
      }

      final saved = await showGoalCheckInDialog(
        context: context,
        goal: goal,
        repository: _checkInRepository,
        checkIn: selected,
        checkInAt: selected?.checkInAt ?? _defaultCheckInAtForDay(day),
      );

      if (saved == true && mounted) {
        await _loadCheckIns();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecordBloc, RecordState>(
      listenWhen: (previous, current) {
        final prevGoal = previous.snapshot.records[widget.goalId];
        final currGoal = current.snapshot.records[widget.goalId];
        return prevGoal?.version != currGoal?.version;
      },
      listener: (context, state) {
        if (widget.initialCheckIns == null) {
          _loadCheckIns();
        }
      },
      builder: (context, state) {
        final goal = _goal(state);
        if (goal == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Goal')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final stats = computeGoalStats(
          goal,
          _checkIns,
          now: _listToday,
        );
        final scheme = Theme.of(context).colorScheme;
        final goalColor =
            parseGoalColor(goal.color, scheme.primary) ?? scheme.primary;
        final backgroundIcon = resolveTaskCategoryIconData(
          iconName: goal.icon,
          defaultIconName: TaskCategoryChipDefaults.goalIcon,
          materialFallback: Icons.flag_outlined,
        );

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                TaskTimelineIconBadge(
                  color: goalColor,
                  iconName: goal.icon,
                  defaultIconName: TaskCategoryChipDefaults.goalIcon,
                  materialFallback: Icons.flag_outlined,
                ),
                const SizedBox(
                  width: CompanionFormStyles.taskPanelIconBadgeGap,
                ),
                Expanded(
                  child: Text(
                    goal.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: scheme.surface.withValues(
              alpha: 0.85,
            ),
            actions: [
              IconButton(
                tooltip: 'Edit goal',
                onPressed: _deleting ? null : () => _openEdit(goal),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete goal',
                onPressed: _deleting ? null : () => _confirmAndDeleteGoal(goal),
                icon: const Icon(Icons.delete_outlined),
              ),
            ],
          ),
          body: AnvilBackgroundIcon(
            icon: backgroundIcon,
            color: goalColor.withValues(alpha: 0.85),
            opacity: 0.32,
            baseSize: 260,
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _buildBody(
                context: context,
                goal: goal,
                stats: stats,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required Goal goal,
    required GoalStats stats,
  }) {
    if (_loadingCheckIns) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_checkInError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _checkInError!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadCheckIns,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final statsSection = GoalStatsSection(
      goal: goal,
      stats: stats,
      checkIns: _checkIns,
      listToday: _listToday,
      displayedMonth: _displayedMonth,
      onPreviousMonth: _showPreviousMonth,
      onNextMonth: _showNextMonth,
      onGoToCurrentMonth: _goToCurrentMonth,
      onDaySelected: (day) => _onCalendarDaySelected(goal, day),
      showHighlightRow: CompanionLayout.isCompact(context),
      showStatCards: CompanionLayout.isCompact(context),
    );

    if (CompanionLayout.isCompact(context)) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GoalDetailHeader(
            goal: goal,
            progressPercent: stats.progressPercent,
          ),
          statsSection,
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GoalDetailSidebar(
          goal: goal,
          stats: stats,
          listToday: _listToday,
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: scheme.outline.withValues(alpha: 0.2),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [statsSection],
          ),
        ),
      ],
    );
  }
}
