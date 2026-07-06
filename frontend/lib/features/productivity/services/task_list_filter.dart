import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';

/// Whether [entry] is in the completed task state.
bool taskListEntryIsCompleted(TaskListEntry entry) =>
    entry.status == 'completed';

/// Whether [item] represents a completed task occurrence or succeeded check-in.
bool timelineItemIsCompleted(
  TimelineSortableItem item, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  return switch (item) {
    TaskTimelineItem(:final entry) => taskListEntryIsCompleted(entry),
    TrackerTimelineItem(:final tracker, :final checkIn) =>
      classifyTrackerCheckIn(tracker, checkIn, now: reference) ==
          TrackerCheckInOutcome.succeeded,
    EventTimelineItem() => false,
  };
}

/// Drops completed task entries when [hideCompleted] is true (default).
List<TaskListEntry> filterVisibleTaskListEntries(
  List<TaskListEntry> entries, {
  bool hideCompleted = true,
}) {
  if (!hideCompleted) return entries;
  return [
    for (final entry in entries)
      if (!taskListEntryIsCompleted(entry)) entry,
  ];
}

/// Drops completed tasks and succeeded tracker check-ins when [hideCompleted].
List<TimelineSortableItem> filterVisibleTimelineItems(
  List<TimelineSortableItem> items, {
  bool hideCompleted = true,
  DateTime? now,
}) {
  if (!hideCompleted) return items;
  final reference = now ?? DateTime.now();
  return [
    for (final item in items)
      if (!timelineItemIsCompleted(item, now: reference)) item,
  ];
}
