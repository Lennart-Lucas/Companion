import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/timeline_row.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

/// Summary buckets shown under the Today header.
enum TaskTodayBucket {
  todo,
  overdue,
  unplanned,
  completed,
}

extension TaskTodayBucketLabels on TaskTodayBucket {
  String get label => switch (this) {
        TaskTodayBucket.todo => 'To Do',
        TaskTodayBucket.overdue => 'Overdue',
        TaskTodayBucket.unplanned => 'Unplanned',
        TaskTodayBucket.completed => 'Completed',
      };
}

/// Counts for each Today bucket card.
class TaskTodayBucketCounts {
  const TaskTodayBucketCounts({
    required this.todo,
    required this.overdue,
    required this.unplanned,
    required this.completed,
  });

  static const zero = TaskTodayBucketCounts(
    todo: 0,
    overdue: 0,
    unplanned: 0,
    completed: 0,
  );

  final int todo;
  final int overdue;
  final int unplanned;
  final int completed;

  int countFor(TaskTodayBucket bucket) => switch (bucket) {
        TaskTodayBucket.todo => todo,
        TaskTodayBucket.overdue => overdue,
        TaskTodayBucket.unplanned => unplanned,
        TaskTodayBucket.completed => completed,
      };
}

DateTime? _entryDeadlineDay(TaskListEntry entry) {
  final deadline = entry.task.deadline;
  if (deadline == null) return null;
  return normalizeTaskListCalendarDay(deadline);
}

bool entryIsUnplanned(TaskListEntry entry) {
  return entry.task.plannedAt == null && entry.task.deadline == null;
}

/// Whether [entry] was completed on [today] (local calendar day).
bool entryCompletedToday(TaskListEntry entry, DateTime today) {
  if (entry.status != 'completed') return false;
  final resolved = entry.resolvedAt ?? entry.displayAt ?? entry.task.updatedAt;
  if (resolved == null) return false;
  return normalizeTaskListCalendarDay(resolved) ==
      normalizeTaskListCalendarDay(today);
}

bool entryMatchesTodoBucket(TaskListEntry entry, DateTime today) {
  if (entry.status == 'completed') return false;
  final deadlineDay = _entryDeadlineDay(entry);
  if (deadlineDay == null) return false;
  final normalizedToday = normalizeTaskListCalendarDay(today);
  return !deadlineDay.isAfter(normalizedToday);
}

bool entryMatchesOverdueBucket(TaskListEntry entry, DateTime today) {
  if (entry.status == 'completed') return false;
  final deadlineDay = _entryDeadlineDay(entry);
  if (deadlineDay == null) return false;
  return deadlineDay.isBefore(normalizeTaskListCalendarDay(today));
}

bool entryMatchesUnplannedBucket(TaskListEntry entry) {
  if (entry.status == 'completed') return false;
  return entryIsUnplanned(entry);
}

/// Whether [entry] belongs in [bucket] when filtering today's task rows.
bool matchesTaskTodayBucket(
  TaskListEntry entry,
  TaskTodayBucket bucket,
  DateTime today,
) {
  return switch (bucket) {
    TaskTodayBucket.todo => entryMatchesTodoBucket(entry, today),
    TaskTodayBucket.overdue => entryMatchesOverdueBucket(entry, today),
    TaskTodayBucket.unplanned => entryMatchesUnplannedBucket(entry),
    TaskTodayBucket.completed => entryCompletedToday(entry, today),
  };
}

/// Mutually exclusive bucket assignment (priority: completed → unplanned → overdue → todo).
TaskTodayBucket? classifyTaskTodayBucket(
  TaskListEntry entry,
  DateTime today,
) {
  if (entryCompletedToday(entry, today)) {
    return TaskTodayBucket.completed;
  }
  if (entryMatchesUnplannedBucket(entry)) {
    return TaskTodayBucket.unplanned;
  }
  if (entryMatchesOverdueBucket(entry, today)) {
    return TaskTodayBucket.overdue;
  }
  if (entryMatchesTodoBucket(entry, today)) {
    return TaskTodayBucket.todo;
  }
  return null;
}

TaskTodayBucketCounts computeTaskTodayBucketCounts(
  Iterable<TaskListEntry> entries,
  DateTime today,
) {
  var todo = 0;
  var overdue = 0;
  var unplanned = 0;
  var completed = 0;

  for (final entry in entries) {
    if (entryCompletedToday(entry, today)) {
      completed++;
    }
    if (entryMatchesUnplannedBucket(entry)) {
      unplanned++;
    }
    if (entryMatchesOverdueBucket(entry, today)) {
      overdue++;
    }
    if (entryMatchesTodoBucket(entry, today)) {
      todo++;
    }
  }

  return TaskTodayBucketCounts(
    todo: todo,
    overdue: overdue,
    unplanned: unplanned,
    completed: completed,
  );
}

/// Entries matching [bucket] for navigation to the bucket detail page.
List<TaskListEntry> taskEntriesForTodayBucket(
  Iterable<TaskListEntry> entries,
  TaskTodayBucket bucket,
  DateTime today,
) {
  return [
    for (final entry in entries)
      if (matchesTaskTodayBucket(entry, bucket, today)) entry,
  ];
}

int? _todayHeaderIndex(List<TimelineRow> rows, DateTime today) {
  final normalizedToday = normalizeTaskListCalendarDay(today);
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row is TimelineDateHeaderRow && row.day != null) {
      if (normalizeTaskListCalendarDay(row.day!) == normalizedToday) {
        return i;
      }
    }
  }
  return null;
}

/// Inserts [TimelineTodayBucketsRow] immediately after the Today date header.
List<TimelineRow> insertTodayBucketsRow(
  List<TimelineRow> rows, {
  required DateTime today,
  required TaskTodayBucketCounts counts,
}) {
  final headerIndex = _todayHeaderIndex(rows, today);
  if (headerIndex == null) return rows;

  final insertAt = headerIndex + 1;
  if (insertAt < rows.length && rows[insertAt] is TimelineTodayBucketsRow) {
    final copy = [...rows];
    copy[insertAt] = TimelineTodayBucketsRow(counts: counts);
    return copy;
  }

  final copy = [...rows];
  copy.insert(insertAt, TimelineTodayBucketsRow(counts: counts));
  return copy;
}

/// Inserts Today bucket cards into [rows].
List<TimelineRow> applyTodayBucketsToTimelineRows({
  required List<TimelineRow> rows,
  required DateTime today,
  required TaskTodayBucketCounts counts,
}) {
  return insertTodayBucketsRow(
    rows,
    today: today,
    counts: counts,
  );
}
