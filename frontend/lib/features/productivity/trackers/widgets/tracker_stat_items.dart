import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';

/// Label/value pairs for tracker summary statistics.
class TrackerStatItem {
  const TrackerStatItem(this.label, this.value);

  final String label;
  final String value;
}

List<TrackerStatItem> buildTrackerStatItems({
  required Tracker tracker,
  required TrackerStats stats,
}) {
  final items = <TrackerStatItem>[
    TrackerStatItem('Current streak', '${stats.currentStreak} days'),
    TrackerStatItem('Best streak', '${stats.bestStreak} days'),
    TrackerStatItem('Total check-ins', '${stats.totalCheckIns}'),
    TrackerStatItem('Succeeded', '${stats.succeeded}'),
    TrackerStatItem(
      tracker.habitDirection == TrackerHabitDirection.quit
          ? 'Exceeded'
          : 'Missed',
      '${stats.missed}',
    ),
    TrackerStatItem('Skipped', '${stats.skipped}'),
  ];

  final quit = tracker.habitDirection == TrackerHabitDirection.quit;

  if (tracker.checkInType == TrackerCheckInType.count) {
    final unit = stats.unitLabel ?? 'units';
    items.addAll([
      TrackerStatItem('Done $unit', _formatNum(stats.doneUnits)),
      TrackerStatItem(
        quit ? 'Exceeded $unit' : 'Missed $unit',
        _formatNum(stats.missedUnits),
      ),
    ]);
  } else if (tracker.checkInType == TrackerCheckInType.duration) {
    final weekTarget = stats.doneMinutes + stats.missedMinutes;
    items.addAll([
      TrackerStatItem(
        'This week',
        weekTarget == 0
            ? '0 min'
            : '${_formatNum(stats.doneMinutes)} / ${_formatNum(weekTarget)} min',
      ),
      if (stats.succeeded > 0)
        TrackerStatItem(
          'Avg / session',
          '${_formatNum(stats.doneMinutes / stats.succeeded)} min',
        ),
      TrackerStatItem('Done minutes', _formatNum(stats.doneMinutes)),
      TrackerStatItem(
        quit ? 'Exceeded minutes' : 'Missed minutes',
        _formatNum(stats.missedMinutes),
      ),
    ]);
  }

  return items;
}

String _formatNum(num value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
