import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/goals/services/goal_health.dart';
import 'package:frontend/features/productivity/goals/services/goal_related_records.dart';
import 'package:frontend/features/productivity/goals/services/goal_stats.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_stat_items.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class GoalHealthOverviewSection extends StatefulWidget {
  const GoalHealthOverviewSection({
    super.key,
    required this.goal,
    required this.stats,
    required this.listToday,
    this.checkInRepository,
  });

  static const _healthTooltip =
      'Health\n\n'
      'Blends goal progress (including pace vs schedule) with the strength '
      'and consistency of linked supporting trackers.\n\n'
      'With trackers: 60% progress score + 40% average tracker support.\n'
      'Without trackers: progress score only.';

  final Goal goal;
  final GoalStats stats;
  final DateTime listToday;
  final TrackerCheckInRepository? checkInRepository;

  @override
  State<GoalHealthOverviewSection> createState() =>
      _GoalHealthOverviewSectionState();
}

class _GoalHealthOverviewSectionState extends State<GoalHealthOverviewSection> {
  GoalHealthOverview? _overview;
  bool _loading = true;
  String? _error;
  List<Tracker> _loadedTrackers = const [];
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchTrackers();
      _reloadFromBloc();
    });
  }

  @override
  void didUpdateWidget(GoalHealthOverviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats != widget.stats ||
        oldWidget.listToday != widget.listToday ||
        oldWidget.goal.id != widget.goal.id) {
      _reloadFromBloc();
    }
  }

  void _prefetchTrackers() {
    if (!mounted) return;
    final bloc = context.read<RecordBloc>();
    if (bloc.state.snapshot.queries[goalRelatedTrackersQuery.queryKey] ==
        null) {
      bloc.add(QueryRecordsRequested(goalRelatedTrackersQuery));
    }
  }

  void _reloadFromBloc() {
    if (!mounted) return;
    final trackers =
        trackersLinkedToGoal(context.read<RecordBloc>().state, widget.goal.id);
    unawaited(_loadHealth(trackers));
  }

  Future<void> _loadHealth(List<Tracker> trackers) async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
      _loadedTrackers = trackers;
    });

    try {
      final repo =
          widget.checkInRepository ?? defaultTrackerCheckInRepository();
      final trackerStats = await Future.wait(
        [
          for (final tracker in trackers)
            repo
                .fetchTrackerHistory(
                  tracker,
                  now: widget.listToday,
                )
                .then(
                  (checkIns) => computeTrackerStats(
                    tracker,
                    checkIns,
                    now: widget.listToday,
                  ),
                ),
        ],
      );

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _overview = computeGoalHealth(
          stats: widget.stats,
          trackerStats: trackerStats,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _overview = computeGoalHealth(
          stats: widget.stats,
          trackerStats: const [],
        );
        _loading = false;
        _error = 'Could not load tracker health';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordBloc, RecordState>(
      listenWhen: (previous, current) {
        final prevTrackers =
            trackersLinkedToGoal(previous, widget.goal.id);
        final currTrackers =
            trackersLinkedToGoal(current, widget.goal.id);
        if (prevTrackers.length != currTrackers.length) return true;
        for (var i = 0; i < currTrackers.length; i++) {
          if (prevTrackers[i].id != currTrackers[i].id) return true;
        }
        return false;
      },
      listener: (context, state) {
        final trackers = trackersLinkedToGoal(state, widget.goal.id);
        if (_trackersChanged(trackers, _loadedTrackers)) {
          unawaited(_loadHealth(trackers));
        }
      },
      child: _GoalHealthOverviewBody(
        overview: _overview,
        stats: widget.stats,
        loading: _loading,
        error: _error,
      ),
    );
  }

  bool _trackersChanged(List<Tracker> next, List<Tracker> current) {
    if (next.length != current.length) return true;
    for (var i = 0; i < next.length; i++) {
      if (next[i].id != current[i].id) return true;
    }
    return false;
  }
}

class _GoalHealthOverviewBody extends StatelessWidget {
  const _GoalHealthOverviewBody({
    required this.overview,
    required this.stats,
    required this.loading,
    this.error,
  });

  final GoalHealthOverview? overview;
  final GoalStats stats;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.55),
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface.withValues(alpha: 0.92),
    );

    final resolvedOverview = overview ??
        computeGoalHealth(stats: stats, trackerStats: const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outline.withValues(alpha: 0.2),
        ),
        const SizedBox(height: 12),
        TrackerRowPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: GoalHealthOverviewSection._healthTooltip,
                      preferBelow: false,
                      waitDuration: const Duration(milliseconds: 200),
                      child: Text(
                        'Health',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (loading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TrackerStrengthBar(
                fraction: (resolvedOverview.score / 100).clamp(0.0, 1.0),
                label:
                    '${formatGoalHealthBand(resolvedOverview.band)} · '
                    '${resolvedOverview.score.round()}%',
                animate: !loading,
              ),
              const SizedBox(height: 8),
              Text(
                resolvedOverview.summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  height: 1.35,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.45),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _HealthRow(
                label: 'Progress score',
                value: '${resolvedOverview.progressScore.round()}%',
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
              const SizedBox(height: 10),
              _HealthRow(
                label: 'Pace',
                value: formatGoalPace(stats.pace),
                labelStyle: labelStyle,
                valueStyle: valueStyle?.copyWith(
                  color: goalPaceColor(stats.pace) ?? valueStyle?.color,
                ),
              ),
              const SizedBox(height: 10),
              _HealthRow(
                label: 'Supporting trackers',
                value: '${resolvedOverview.linkedTrackerCount}',
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
              if (resolvedOverview.averageTrackerStrength != null) ...[
                const SizedBox(height: 10),
                _HealthRow(
                  label: 'Avg habit strength',
                  value:
                      '${resolvedOverview.averageTrackerStrength!.round()}%',
                  labelStyle: labelStyle,
                  valueStyle: valueStyle,
                ),
              ],
              if (resolvedOverview.averageTrackerConsistency != null) ...[
                const SizedBox(height: 10),
                _HealthRow(
                  label: 'Avg consistency',
                  value:
                      '${(resolvedOverview.averageTrackerConsistency! * 100).round()}%',
                  labelStyle: labelStyle,
                  valueStyle: valueStyle,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: valueStyle,
        ),
      ],
    );
  }
}
