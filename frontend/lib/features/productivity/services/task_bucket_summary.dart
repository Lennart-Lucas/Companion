import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/services/task_list_builder.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';

enum TaskBucket { today, overdue, unplanned, completed }

String taskBucketLabel(TaskBucket bucket) => switch (bucket) {
      TaskBucket.today => 'To Do',
      TaskBucket.overdue => 'Overdue',
      TaskBucket.unplanned => 'Unplanned',
      TaskBucket.completed => 'Completed',
    };

String taskBucketEmptyMessage(TaskBucket bucket) => switch (bucket) {
      TaskBucket.overdue => 'No overdue tasks',
      TaskBucket.today => 'No tasks to do',
      TaskBucket.unplanned => 'No unplanned tasks',
      TaskBucket.completed => 'No tasks completed today',
    };

class TaskBucketSummary {
  const TaskBucketSummary({
    required this.overdue,
    required this.today,
    required this.unplanned,
    required this.completed,
  });

  static const empty = TaskBucketSummary(
    overdue: [],
    today: [],
    unplanned: [],
    completed: [],
  );

  final List<TaskListEntry> overdue;
  final List<TaskListEntry> today;
  final List<TaskListEntry> unplanned;
  final List<TaskListEntry> completed;

  int count(TaskBucket bucket) => entriesForBucket(bucket).length;

  List<TaskListEntry> entriesForBucket(TaskBucket bucket) => switch (bucket) {
        TaskBucket.overdue => overdue,
        TaskBucket.today => today,
        TaskBucket.unplanned => unplanned,
        TaskBucket.completed => completed,
      };
}

/// Display order for bucket cards (To Do → Overdue → Unplanned → Completed).
const taskBucketDisplayOrder = [
  TaskBucket.today,
  TaskBucket.overdue,
  TaskBucket.unplanned,
  TaskBucket.completed,
];

DateTime taskBucketLocalDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime taskBucketToday({DateTime? now}) =>
    taskBucketLocalDay(now ?? DateTime.now());

bool taskBucketDayIsBefore(DateTime day, DateTime reference) =>
    taskBucketLocalDay(day).isBefore(taskBucketLocalDay(reference));

bool taskBucketDayIsOnOrBefore(DateTime day, DateTime reference) =>
    !taskBucketLocalDay(day).isAfter(taskBucketLocalDay(reference));

bool taskBucketDayIsSame(DateTime day, DateTime reference) =>
    taskBucketLocalDay(day) == taskBucketLocalDay(reference);

bool taskCompletedOnLocalDay(Task task, DateTime today) {
  if (task.status != 'completed') return false;
  final resolved = task.updatedAt;
  return resolved != null && taskBucketDayIsSame(resolved, today);
}

bool taskEntryCompletedOnLocalDay(TaskListEntry entry, DateTime today) {
  if (entry.status != 'completed') return false;
  final resolved = entry.resolvedAt ?? entry.task.updatedAt;
  return resolved != null && taskBucketDayIsSame(resolved, today);
}

TaskListEntry taskListEntryFromTask(Task task) {
  final at = task.plannedAt ?? task.deadline;
  final resolvedAt =
      taskListStatusIsTerminal(task.status) ? task.updatedAt : null;
  return applyTaskListDisplayRules(
    TaskListEntry(
      task: task,
      occurrenceAt: at,
      status: task.status,
      priority: task.priority,
      subtasks: TaskListEntry.defaultSubtasks(task),
      isVirtual: true,
      resolvedAt: resolvedAt,
    ),
  );
}

/// Classifies a non-recurring [task] or synthesised entry for bucket assignment.
TaskBucket? classifyTaskForBucket(Task task, DateTime today) {
  if (taskListStatusIsTerminal(task.status)) return null;
  if (!taskListNonRecurringIsVisible(task)) {
    return TaskBucket.unplanned;
  }

  final deadline = task.deadline;
  if (deadline != null && taskBucketDayIsBefore(deadline, today)) {
    return TaskBucket.overdue;
  }

  final planned = task.plannedAt;
  if ((planned != null && taskBucketDayIsOnOrBefore(planned, today)) ||
      (deadline != null && taskBucketDayIsOnOrBefore(deadline, today))) {
    return TaskBucket.today;
  }

  return null;
}

/// Classifies a timeline [entry] (including recurring occurrences).
TaskBucket? classifyEntryForBucket(TaskListEntry entry, DateTime today) {
  if (taskListStatusIsTerminal(entry.status)) return null;

  final task = entry.task;
  final deadline = task.deadline;
  if (deadline != null && taskBucketDayIsBefore(deadline, today)) {
    return TaskBucket.overdue;
  }

  final anchor = entry.occurrenceAt ?? task.plannedAt ?? task.deadline;
  if (anchor != null && taskBucketDayIsOnOrBefore(anchor, today)) {
    return TaskBucket.today;
  }

  return null;
}

int _compareEntries(TaskListEntry a, TaskListEntry b) {
  final aDate = a.displayAt ?? taskListEntryScheduledAt(a);
  final bDate = b.displayAt ?? taskListEntryScheduledAt(b);
  if (aDate == null && bDate == null) {
    return a.task.name.compareTo(b.task.name);
  }
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  final cmp = aDate.compareTo(bDate);
  return cmp != 0 ? cmp : a.task.name.compareTo(b.task.name);
}

List<TaskListEntry> _sorted(List<TaskListEntry> entries) {
  final copy = [...entries];
  copy.sort(_compareEntries);
  return copy;
}

Future<TaskBucketSummary> computeTaskBucketSummary({
  required List<Task> tasks,
  required TaskListBuilder builder,
  DateTime? now,
}) async {
  final today = taskBucketToday(now: now);
  final horizon = TaskListHorizon.forLocalDays(
    taskListOverdueSweepWindow().localFromDay,
    today,
  );

  final unplanned = <TaskListEntry>[];
  final dated = <Task>[];

  for (final task in tasks) {
    if (taskListStatusIsTerminal(task.status)) continue;
    if (!taskListNonRecurringIsVisible(task)) {
      unplanned.add(taskListEntryFromTask(task));
    } else {
      dated.add(task);
    }
  }

  final overdue = <TaskListEntry>[];
  final todayEntries = <TaskListEntry>[];
  final completed = <TaskListEntry>[];
  final seen = <String>{};
  final completedSeen = <String>{};

  void add(TaskBucket bucket, TaskListEntry entry) {
    if (!seen.add(entry.listKey)) return;
    switch (bucket) {
      case TaskBucket.overdue:
        overdue.add(entry);
      case TaskBucket.today:
        todayEntries.add(entry);
      case TaskBucket.unplanned:
      case TaskBucket.completed:
        break;
    }
  }

  void addCompleted(TaskListEntry entry) {
    if (!completedSeen.add(entry.listKey)) return;
    completed.add(entry);
  }

  for (final entry in unplanned) {
    seen.add(entry.listKey);
  }

  final built = await builder.build(dated, horizon: horizon);
  for (final entry in built) {
    final bucket = classifyEntryForBucket(entry, today);
    if (bucket != null) {
      add(bucket, entry);
    }
  }

  // Non-recurring dated tasks may not appear in builder output when outside horizon
  // filters; classify directly so counts stay accurate.
  for (final task in dated) {
    if (task.isRecurring) continue;
    final bucket = classifyTaskForBucket(task, today);
    if (bucket == null) continue;
    add(bucket, taskListEntryFromTask(task));
  }

  for (final task in tasks) {
    if (task.isRecurring) continue;
    if (!taskCompletedOnLocalDay(task, today)) continue;
    addCompleted(taskListEntryFromTask(task));
  }

  final recurring = tasks.where((task) => task.isRecurring).toList();
  if (recurring.isNotEmpty) {
    final recurringBuilt = await builder.build(recurring, horizon: horizon);
    for (final entry in recurringBuilt) {
      if (taskEntryCompletedOnLocalDay(entry, today)) {
        addCompleted(entry);
      }
    }
    for (final task in recurring) {
      if (taskCompletedOnLocalDay(task, today)) {
        addCompleted(taskListEntryFromTask(task));
      }
    }
  }

  return TaskBucketSummary(
    overdue: _sorted(overdue),
    today: _sorted(todayEntries),
    unplanned: _sorted(unplanned),
    completed: _sorted(completed),
  );
}
