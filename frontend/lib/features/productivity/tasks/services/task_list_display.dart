import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';

/// Whether [status] is a terminal task list state.
bool taskListStatusIsTerminal(String status) =>
    status == 'completed' || status == 'cancelled';

/// Original scheduled / repeat anchor for a list entry.
DateTime? taskListEntryScheduledAt(TaskListEntry entry) =>
    entry.occurrenceAt ?? entry.task.plannedAt ?? entry.task.deadline;

/// Whether a non-recurring task should appear in the list at all.
bool taskListNonRecurringIsVisible(Task task) =>
    task.plannedAt != null || task.deadline != null;

DateTime _localDayStart(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

bool _localDayIsBefore(DateTime day, DateTime reference) =>
    _localDayStart(day).isBefore(_localDayStart(reference));

DateTime _driftToToday(DateTime scheduledAt, DateTime today) {
  final localScheduled = scheduledAt.toLocal();
  if (localScheduled.hour == 0 &&
      localScheduled.minute == 0 &&
      localScheduled.second == 0) {
    return today;
  }
  return today.add(
    Duration(
      hours: localScheduled.hour,
      minutes: localScheduled.minute,
      seconds: localScheduled.second,
    ),
  );
}

bool _entryIsPastDue(TaskListEntry entry, DateTime scheduledAt, DateTime now) {
  if (entry.task.isRecurring && entry.occurrenceAt != null) {
    return _localDayIsBefore(scheduledAt, now);
  }
  final deadline = entry.task.deadline;
  if (deadline == null) return false;
  return _localDayIsBefore(deadline, now);
}

/// Applies drift, completion anchoring, and past-due flags to [entry].
TaskListEntry applyTaskListDisplayRules(
  TaskListEntry entry, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = _localDayStart(current);
  final scheduledAt = taskListEntryScheduledAt(entry);

  if (scheduledAt == null) {
    return entry.copyWith(displayAt: null, isPastDue: false);
  }

  final isTerminal = taskListStatusIsTerminal(entry.status);
  final DateTime displayAt;

  if (isTerminal) {
    displayAt = entry.resolvedAt ?? scheduledAt;
  } else if (_localDayIsBefore(scheduledAt, current)) {
    displayAt = _driftToToday(scheduledAt, today);
  } else {
    displayAt = scheduledAt;
  }

  final isPastDue =
      !isTerminal && _entryIsPastDue(entry, scheduledAt, current);

  return entry.copyWith(displayAt: displayAt, isPastDue: isPastDue);
}

/// Whether [entry]'s display date falls within [horizon].
bool taskListEntryDisplayInHorizon(
  TaskListEntry entry,
  TaskListHorizon horizon,
) {
  final at = entry.displayAt ?? taskListEntryScheduledAt(entry);
  if (at == null) return false;
  return taskListDateInHorizon(at, horizon);
}
