import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/shared/models/timeline_item.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';

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
    GoalTimelineItem(:final checkIn) => checkIn.logged,
    EventTimelineItem() => false,
  };
}

/// Whether a completed item should be hidden when [hideCompleted] is enabled.
///
/// Completed items on past calendar days remain visible; only today and future
/// days (plus undated items) hide completed entries.
bool shouldHideCompletedTimelineItem(
  TimelineSortableItem item, {
  required bool hideCompleted,
  DateTime? listToday,
}) {
  if (!hideCompleted) return false;
  if (!timelineItemIsCompleted(item, now: DateTime.now())) return false;

  final day = item.localDay;
  if (day != null &&
      taskListDayIsBeforeToday(day, now: listToday ?? DateTime.now())) {
    return false;
  }
  return true;
}

/// Whether a completed task entry should be hidden when [hideCompleted] is on.
bool shouldHideCompletedTaskListEntry(
  TaskListEntry entry, {
  required bool hideCompleted,
  DateTime? now,
}) {
  if (!hideCompleted) return false;
  if (!taskListEntryIsCompleted(entry)) return false;

  final day = taskListEntryLocalDay(entry);
  if (day != null && taskListDayIsBeforeToday(day, now: now)) {
    return false;
  }
  return true;
}

/// Drops completed task entries when [hideCompleted] is true (default).
///
/// Completed entries on past calendar days are kept visible.
List<TaskListEntry> filterVisibleTaskListEntries(
  List<TaskListEntry> entries, {
  bool hideCompleted = true,
  DateTime? now,
}) {
  if (!hideCompleted) return entries;
  return [
    for (final entry in entries)
      if (!shouldHideCompletedTaskListEntry(
        entry,
        hideCompleted: hideCompleted,
        now: now,
      ))
        entry,
  ];
}

/// Drops completed tasks and succeeded tracker check-ins when [hideCompleted].
///
/// Completed items on past calendar days are kept visible.
List<TimelineSortableItem> filterVisibleTimelineItems(
  List<TimelineSortableItem> items, {
  bool hideCompleted = true,
  DateTime? listToday,
}) {
  if (!hideCompleted) return items;
  return [
    for (final item in items)
      if (!shouldHideCompletedTimelineItem(
        item,
        hideCompleted: hideCompleted,
        listToday: listToday,
      ))
        item,
  ];
}
