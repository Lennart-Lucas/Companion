import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_tile_stats_loader.dart';

/// @deprecated Use [TrackerListTileStatsLoader] instead.
@Deprecated('Use TrackerListTileStatsLoader')
class TrackerStrengthBarLoader extends StatelessWidget {
  const TrackerStrengthBarLoader({
    super.key,
    required this.tracker,
    this.repository,
    this.listToday,
  });

  final Tracker tracker;
  final TrackerCheckInRepository? repository;
  final DateTime? listToday;

  @override
  Widget build(BuildContext context) {
    return TrackerListTileStatsLoader(
      tracker: tracker,
      repository: repository,
      listToday: listToday,
      builder: (context, stats) {
        return TrackerStrengthBar(
          fraction: stats.habitStrength / 100,
          animate: !stats.loading,
        );
      },
    );
  }
}
