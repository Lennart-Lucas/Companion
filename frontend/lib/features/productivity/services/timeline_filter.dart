import 'package:frontend/features/productivity/models/goal_check_in.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/goal_check_in_timeline_tile.dart';

/// Optional visibility rules for productivity timeline content.
class ProductivityTimelineFilter {
  const ProductivityTimelineFilter({this.hideFinished = false});

  /// When true, hides tasks and tracker check-ins that are done or cancelled.
  final bool hideFinished;

  static const showAll = ProductivityTimelineFilter();
  static const activeOnly = ProductivityTimelineFilter(hideFinished: true);
}

/// Whether [item] is finished and can be hidden by [ProductivityTimelineFilter].
bool timelineItemIsFinished(
  TimelineSortableItem item, {
  required DateTime now,
}) {
  return switch (item) {
    TaskTimelineItem(:final entry) => taskListStatusIsTerminal(entry.status),
    TrackerTimelineItem(:final tracker, :final checkIn) =>
      trackerCheckInIsFinished(tracker, checkIn, now: now),
    GoalTimelineItem(:final goal, :final checkIn) =>
      goalCheckInIsFinished(goal, checkIn, now: now),
    EventTimelineItem() => false,
  };
}

bool goalCheckInIsFinished(
  Goal goal,
  GoalCheckIn checkIn, {
  required DateTime now,
}) {
  final outcome = classifyGoalCheckIn(goal, checkIn, now: now);
  return outcome != GoalCheckInOutcome.pending;
}

/// Whether [checkIn] is resolved (done, missed, or skipped).
bool trackerCheckInIsFinished(
  Tracker tracker,
  TrackerCheckIn checkIn, {
  required DateTime now,
}) {
  final outcome = classifyTrackerCheckIn(tracker, checkIn, now: now);
  return outcome != TrackerCheckInOutcome.pending;
}

/// Applies [filter] to timeline [items].
List<TimelineSortableItem> applyTimelineFilter(
  List<TimelineSortableItem> items,
  ProductivityTimelineFilter filter, {
  required DateTime now,
}) {
  if (!filter.hideFinished) return items;
  return [
    for (final item in items)
      if (!timelineItemIsFinished(item, now: now)) item,
  ];
}
