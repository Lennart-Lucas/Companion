import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/typed_record_resolver.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_display.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';

/// Shared tasks list query used for project progress on list/detail screens.
const projectTasksListQuery = RecordQuery(recordType: 'tasks', limit: 50);

String projectStatusLabel(String value) => switch (value) {
      'planning' => 'Planning',
      'active' => 'Active',
      'on_hold' => 'On hold',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => value,
    };

String formatProjectDate(DateTime date) {
  final local = date.toLocal();
  final y = local.year.toString();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses `#RRGGBB` or `RRGGBB`. Returns null if invalid.
Color? parseProjectColor(String? hex, Color fallback) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('#')) {
    value = value.substring(1);
  }
  if (value.length != 6) return null;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

String? projectDateRangeLabel(DateTime? start, DateTime? deadline) {
  if (start != null && deadline != null) {
    return '${formatProjectDate(start)} – ${formatProjectDate(deadline)}';
  }
  if (start != null) {
    return 'From ${formatProjectDate(start)}';
  }
  if (deadline != null) {
    return 'Due ${formatProjectDate(deadline)}';
  }
  return null;
}

/// Task completion stats for a project (from cached [RecordBloc] tasks).
class ProjectTaskProgress {
  const ProjectTaskProgress({required this.total, required this.completed});

  final int total;
  final int completed;

  double get fraction => total == 0 ? 0 : completed / total;
}

/// Formats task completion for project list tiles.
String formatProjectTaskProgressLabel(
  ProjectTaskProgress progress, {
  required bool compact,
}) {
  if (progress.total == 0) {
    return compact ? 'No tasks' : 'No tasks yet';
  }
  if (compact) return '${progress.completed}/${progress.total}';
  return '${progress.completed}/${progress.total} tasks done';
}

ProjectTaskProgress projectTaskProgressForProject(
  Iterable<Record?> records,
  String projectId,
) {
  var total = 0;
  var completed = 0;
  for (final record in records) {
    if (record is! Task) continue;
    if (record.projectId != projectId) continue;
    total++;
    if (record.status == 'completed') completed++;
  }
  return ProjectTaskProgress(total: total, completed: completed);
}

/// Resolves tasks from the cached tasks query (with local-cache fallback) before
/// counting progress for [projectId].
Future<ProjectTaskProgress> resolveProjectTaskProgress(
  RecordState state,
  String projectId,
) async {
  final cached = state.snapshot.queries[projectTasksListQuery.queryKey];
  if (cached == null) {
    return const ProjectTaskProgress(total: 0, completed: 0);
  }

  final tasks = await resolveTypedRecords<Task>(
    state: state,
    recordType: 'tasks',
    recordIds: cached.recordIds,
    cache: CompanionAnvilApp.instance.localCache,
    registry: buildCompanionRecordRegistry(),
  );
  return projectTaskProgressForProject(tasks, projectId);
}

/// Linked tasks for [projectId], resolved from the tasks query cache.
Future<List<Task>> resolveLinkedTasksForProject(
  RecordState state,
  String projectId,
) async {
  final cached = state.snapshot.queries[projectTasksListQuery.queryKey];
  if (cached == null) return const [];

  final tasks = await resolveTypedRecords<Task>(
    state: state,
    recordType: 'tasks',
    recordIds: cached.recordIds,
    cache: CompanionAnvilApp.instance.localCache,
    registry: buildCompanionRecordRegistry(),
  );
  return tasksForProject(tasks, projectId);
}

/// All tasks linked to [projectId] from cached [RecordBloc] records.
List<Task> tasksForProject(
  Iterable<Record?> records,
  String projectId,
) {
  final tasks = <Task>[];
  for (final record in records) {
    if (record is! Task) continue;
    if (record.projectId != projectId) continue;
    tasks.add(record);
  }
  tasks.sort((a, b) {
    final aDate = a.plannedAt ?? a.deadline;
    final bDate = b.plannedAt ?? b.deadline;
    if (aDate == null && bDate == null) {
      return a.name.compareTo(b.name);
    }
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final cmp = aDate.compareTo(bDate);
    return cmp != 0 ? cmp : a.name.compareTo(b.name);
  });
  return tasks;
}

/// Calendar span for the project detail task list.
///
/// Uses the earliest and latest local day among [project] dates and linked
/// [tasks] `plannedAt` / `deadline`. Returns null when no dated bounds exist.
TaskListHorizon? projectTaskListHorizon({
  required Project project,
  required Iterable<Task> tasks,
}) {
  DateTime? fromDay;
  DateTime? toDay;

  void consider(DateTime? date) {
    if (date == null) return;
    final day = normalizeTaskListCalendarDay(date);
    fromDay = fromDay == null || day.isBefore(fromDay!) ? day : fromDay;
    toDay = toDay == null || day.isAfter(toDay!) ? day : toDay;
  }

  consider(project.startDate);
  consider(project.deadline);
  for (final task in tasks) {
    consider(task.plannedAt);
    consider(task.deadline);
  }

  if (fromDay == null || toDay == null) return null;

  final today = taskListLocalToday();
  var horizonTo = toDay!;
  for (final task in tasks) {
    if (taskListStatusIsTerminal(task.status)) continue;
    if (task.isRecurring) {
      if (horizonTo.isBefore(today)) horizonTo = today;
      continue;
    }
    final at = task.plannedAt ?? task.deadline;
    if (at == null) continue;
    if (normalizeTaskListCalendarDay(at).isBefore(today) &&
        horizonTo.isBefore(today)) {
      horizonTo = today;
    }
  }

  return TaskListHorizon.forLocalDays(fromDay!, horizonTo);
}

/// Linked tasks with no planned or deadline date.
List<Task> undatedTasksForProject(Iterable<Task> tasks) {
  return tasks
      .where((task) => !taskListNonRecurringIsVisible(task))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
}
