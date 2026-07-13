import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/companion_routes.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/shared/services/timeline_feed.dart';
import 'package:frontend/features/productivity/shared/services/weekly_summary_service.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_check_ins.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_goals_section.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_header.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_projects_section.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_recap_section.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_trackers_section.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';

/// Dashboard for a single Monday–Sunday productivity week.
class WeeklySummaryPage extends StatefulWidget {
  const WeeklySummaryPage({
    super.key,
    required this.weekStart,
    this.summaryService,
    this.listToday,
    this.goalCheckInRepository,
    this.trackerCheckInRepository,
  });

  final DateTime weekStart;
  final WeeklySummaryService? summaryService;
  final DateTime? listToday;
  final GoalCheckInRepository? goalCheckInRepository;
  final TrackerCheckInRepository? trackerCheckInRepository;

  @override
  State<WeeklySummaryPage> createState() => _WeeklySummaryPageState();
}

class _WeeklySummaryPageState extends State<WeeklySummaryPage> {
  static const _projectsQuery = RecordQuery(recordType: 'projects', limit: 50);

  static const _summaryQueries = [
    TaskTimelineProvider.tasksQuery,
    GoalTimelineProvider.goalsQuery,
    TrackerTimelineProvider.trackersQuery,
    _projectsQuery,
  ];

  late DateTime _weekStart;
  late DateTime _listToday;
  WeeklySummary? _summary;
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  WeeklySummaryService get _service =>
      widget.summaryService ?? WeeklySummaryService();

  GoalCheckInRepository get _goalCheckInRepository =>
      widget.goalCheckInRepository ?? defaultGoalCheckInRepository();

  TrackerCheckInRepository get _trackerCheckInRepository =>
      widget.trackerCheckInRepository ?? defaultTrackerCheckInRepository();

  @override
  void initState() {
    super.initState();
    _weekStart = normalizeTaskListCalendarDay(widget.weekStart);
    _listToday = normalizeTaskListCalendarDay(
      widget.listToday ?? DateTime.now(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchQueries();
    });
    _loadSummary();
  }

  void _prefetchQueries() {
    final bloc = context.read<RecordBloc>();
    final snapshot = bloc.state.snapshot;
    for (final query in _summaryQueries) {
      if (snapshot.queries[query.queryKey] == null) {
        bloc.add(QueryRecordsRequested(query));
      }
    }
  }

  int _hydratedSummaryRecordCount(RecordState state) {
    var count = 0;
    for (final query in _summaryQueries) {
      final cached = state.snapshot.queries[query.queryKey];
      if (cached == null) continue;
      for (final id in cached.recordIds) {
        if (state.snapshot.records[id]?.record != null) count++;
      }
    }
    return count;
  }

  bool _shouldReloadSummary(RecordState previous, RecordState current) {
    for (final query in _summaryQueries) {
      final key = query.queryKey;
      final prevVersion = previous.snapshot.queries[key]?.version ?? -1;
      final currVersion = current.snapshot.queries[key]?.version ?? -1;
      if (currVersion > prevVersion) return true;
    }
    return _hydratedSummaryRecordCount(previous) <
        _hydratedSummaryRecordCount(current);
  }

  @override
  void didUpdateWidget(WeeklySummaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextWeekStart = normalizeTaskListCalendarDay(widget.weekStart);
    if (nextWeekStart != _weekStart) {
      _weekStart = nextWeekStart;
      _loadSummary();
    }
    final nextListToday = normalizeTaskListCalendarDay(
      widget.listToday ?? DateTime.now(),
    );
    if (nextListToday != _listToday) {
      _listToday = nextListToday;
    }
  }

  Future<void> _loadSummary() async {
    final generation = ++_loadGeneration;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final state = context.read<RecordBloc>().state;
      final summary = await _service.compute(
        state: state,
        weekStart: _weekStart,
        listToday: _listToday,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _navigateToWeek(DateTime weekStart) {
    context.replace(CompanionRoutes.weeklySummary(weekStart));
  }

  void _showPreviousWeek() {
    _navigateToWeek(_weekStart.subtract(const Duration(days: 7)));
  }

  void _showNextWeek() {
    _navigateToWeek(_weekStart.add(const Duration(days: 7)));
  }

  void _goToCurrentWeek() {
    _navigateToWeek(taskListWeekStart(_listToday));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordBloc, RecordState>(
      listenWhen: _shouldReloadSummary,
      listener: (context, state) => _loadSummary(),
      child: Scaffold(
        appBar: WeeklySummaryHeader(
          weekStart: _weekStart,
          listToday: _listToday,
          onPreviousWeek: _showPreviousWeek,
          onNextWeek: _showNextWeek,
          onGoToCurrentWeek: _goToCurrentWeek,
        ),
        body: RefreshIndicator(
          onRefresh: _loadSummary,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _loadSummary, child: const Text('Retry')),
        ],
      );
    }

    final summary = _summary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    final checkIns = WeeklySummaryCheckIns(
      context: context,
      goalRepository: _goalCheckInRepository,
      trackerRepository: _trackerCheckInRepository,
      onSaved: _loadSummary,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      cacheExtent: 1200,
      children: [
        WeeklySummaryRecapSection(recap: summary.recap),
        const SizedBox(height: CompanionFormStyles.sectionHeaderMarginTop),
        WeeklySummaryGoalsSection(
          goals: summary.goals,
          weekStart: _weekStart,
          listToday: _listToday,
          checkIns: checkIns,
        ),
        const SizedBox(height: CompanionFormStyles.sectionHeaderMarginTop),
        WeeklySummaryTrackersSection(
          trackers: summary.trackers,
          weekStart: _weekStart,
          listToday: _listToday,
          checkIns: checkIns,
        ),
        const SizedBox(height: CompanionFormStyles.sectionHeaderMarginTop),
        WeeklySummaryProjectsSection(projects: summary.projects),
      ],
    );
  }
}
