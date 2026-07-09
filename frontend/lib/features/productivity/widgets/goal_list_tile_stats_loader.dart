import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/services/goal_stats.dart';

/// Snapshot of goal stats shown on list tiles.
class GoalListTileStats {
  const GoalListTileStats({
    required this.progressPercent,
    required this.currentStreak,
    required this.loading,
  });

  final double progressPercent;
  final int currentStreak;
  final bool loading;

  static const loadingPlaceholder = GoalListTileStats(
    progressPercent: 0,
    currentStreak: 0,
    loading: true,
  );
}

typedef GoalListTileStatsBuilder = Widget Function(
  BuildContext context,
  GoalListTileStats stats,
);

/// Loads check-ins and supplies progress + streak for list tiles.
class GoalListTileStatsLoader extends StatefulWidget {
  const GoalListTileStatsLoader({
    super.key,
    required this.goal,
    required this.builder,
    this.repository,
    this.listToday,
  });

  final Goal goal;
  final GoalListTileStatsBuilder builder;
  final GoalCheckInRepository? repository;
  final DateTime? listToday;

  @override
  State<GoalListTileStatsLoader> createState() =>
      _GoalListTileStatsLoaderState();
}

class _GoalListTileStatsLoaderState extends State<GoalListTileStatsLoader> {
  GoalListTileStats _stats = GoalListTileStats.loadingPlaceholder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GoalListTileStatsLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal.id != widget.goal.id ||
        oldWidget.listToday != widget.listToday) {
      setState(() => _stats = GoalListTileStats.loadingPlaceholder);
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final repo = widget.repository ?? defaultGoalCheckInRepository();
      final reference = widget.listToday ?? DateTime.now();
      final checkIns = await repo.fetchGoalHistory(
        widget.goal,
        now: reference,
      );
      if (!mounted) return;
      final computed = computeGoalStats(
        widget.goal,
        checkIns,
        now: reference,
      );
      setState(() {
        _stats = GoalListTileStats(
          progressPercent: computed.progressPercent,
          currentStreak: computed.currentStreak,
          loading: false,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stats = const GoalListTileStats(
          progressPercent: 0,
          currentStreak: 0,
          loading: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _stats);
  }
}
