import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';

String formatTaskDeadline(DateTime deadline) {
  final local = deadline.toLocal();
  final y = local.year.toString();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatTaskOccurrenceDate(DateTime date) => formatTaskDeadline(date);

String? formatTaskListTime(TaskListEntry entry) {
  final dt =
      entry.occurrenceAt ?? entry.task.plannedAt ?? entry.task.deadline;
  if (dt == null) return null;

  final local = dt.toLocal();
  if (local.hour == 0 && local.minute == 0 && local.second == 0) {
    return formatTaskDeadline(local);
  }

  final hour = local.hour;
  final minute = local.minute;
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final minuteStr = minute.toString().padLeft(2, '0');
  return '$hour12:$minuteStr $period';
}

bool taskListTimeShowsClock(TaskListEntry entry) {
  final dt =
      entry.occurrenceAt ?? entry.task.plannedAt ?? entry.task.deadline;
  if (dt == null) return false;
  final local = dt.toLocal();
  return local.hour != 0 || local.minute != 0 || local.second != 0;
}

DateTime? taskListEntryLocalDay(TaskListEntry entry) {
  final dt = entry.displayAt ??
      entry.occurrenceAt ??
      entry.task.plannedAt ??
      entry.task.deadline;
  if (dt == null) return null;
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}