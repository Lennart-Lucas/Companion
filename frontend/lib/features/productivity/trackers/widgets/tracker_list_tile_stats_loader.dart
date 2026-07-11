import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';

/// Snapshot of tracker stats shown on list tiles.
class TrackerListTileStats {
  const TrackerListTileStats({
    required this.habitStrength,
    required this.currentStreak,
    required this.loading,
  });

  final double habitStrength;
  final int currentStreak;
  final bool loading;

  static const loadingPlaceholder = TrackerListTileStats(
    habitStrength: 0,
    currentStreak: 0,
    loading: true,
  );
}

typedef TrackerListTileStatsBuilder = Widget Function(
  BuildContext context,
  TrackerListTileStats stats,
);

/// Loads check-ins and supplies habit strength + streak for list tiles.
class TrackerListTileStatsLoader extends StatefulWidget {
  const TrackerListTileStatsLoader({
    super.key,
    required this.tracker,
    required this.builder,
    this.repository,
    this.listToday,
  });

  final Tracker tracker;
  final TrackerListTileStatsBuilder builder;
  final TrackerCheckInRepository? repository;
  final DateTime? listToday;

  @override
  State<TrackerListTileStatsLoader> createState() =>
      _TrackerListTileStatsLoaderState();
}

class _TrackerListTileStatsLoaderState extends State<TrackerListTileStatsLoader> {
  TrackerListTileStats _stats = TrackerListTileStats.loadingPlaceholder;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TrackerListTileStatsLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracker.id != widget.tracker.id ||
        oldWidget.listToday != widget.listToday) {
      setState(() => _stats = TrackerListTileStats.loadingPlaceholder);
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final repo = widget.repository ?? defaultTrackerCheckInRepository();
      final reference = widget.listToday ?? DateTime.now();
      final checkIns = await repo.fetchTrackerHistory(
        widget.tracker,
        now: reference,
      );
      if (!mounted) return;
      final computed = computeTrackerStats(
        widget.tracker,
        checkIns,
        now: reference,
      );
      setState(() {
        _stats = TrackerListTileStats(
          habitStrength: computed.habitStrength,
          currentStreak: computed.currentStreak,
          loading: false,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stats = const TrackerListTileStats(
          habitStrength: 0,
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
