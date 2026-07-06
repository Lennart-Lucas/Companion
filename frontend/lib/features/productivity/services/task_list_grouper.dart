import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/models/timeline_row.dart';
import 'package:frontend/features/productivity/services/task_list_builder.dart';
import 'package:frontend/features/productivity/services/timeline_grouper.dart';

/// Tasks sharing one calendar day (null day = unscheduled).
class TaskListDaySection {
  const TaskListDaySection({
    required this.day,
    required this.entries,
  });

  final DateTime? day;
  final List<TaskListEntry> entries;
}

/// One row in the flattened infinite-scroll task list.
sealed class TaskListRow {}

class TaskListDateHeaderRow extends TaskListRow {
  TaskListDateHeaderRow({required this.day});

  final DateTime? day;
}

class TaskListEntryRow extends TaskListRow {
  TaskListEntryRow({
    required this.entry,
    required this.isFirstInDay,
    required this.isLastInDay,
  });

  final TaskListEntry entry;
  final bool isFirstInDay;
  final bool isLastInDay;
}

class TaskListLoadingRow extends TaskListRow {
  TaskListLoadingRow({required this.isPast});

  final bool isPast;
}

class TaskListAddRow extends TaskListRow {
  TaskListAddRow({required this.hasTasksAbove, this.day});

  final bool hasTasksAbove;
  final DateTime? day;
}

List<TimelineDaySection> _toTimelineSections(List<TaskListDaySection> sections) {
  return [
    for (final section in sections)
      TimelineDaySection(
        day: section.day,
        items: section.entries.map(TaskTimelineItem.new).toList(),
      ),
  ];
}

List<TaskListDaySection> _fromTimelineSections(List<TimelineDaySection> sections) {
  return [
    for (final section in sections)
      TaskListDaySection(
        day: section.day,
        entries: [
          for (final item in section.items)
            if (item is TaskTimelineItem) item.entry,
        ],
      ),
  ];
}

TaskListRow _fromTimelineRow(TimelineRow row) {
  return switch (row) {
    TimelineDateHeaderRow(:final day) => TaskListDateHeaderRow(day: day),
    TimelineTaskEntryRow(
      :final entry,
      :final isFirstInDay,
      :final isLastInDay,
    ) =>
      TaskListEntryRow(
        entry: entry,
        isFirstInDay: isFirstInDay,
        isLastInDay: isLastInDay,
      ),
    TimelineLoadingRow(:final isPast) => TaskListLoadingRow(isPast: isPast),
    TimelineAddTaskRow(:final hasTasksAbove, :final day) => TaskListAddRow(
        hasTasksAbove: hasTasksAbove,
        day: day,
      ),
    TimelineTaskBucketRow() => throw StateError(
        'Task list rows cannot include bucket rows',
      ),
    TimelineEventEntryRow() => throw StateError(
        'Task list rows cannot include event entries',
      ),
    TimelineTrackerCheckInRow() => throw StateError(
        'Task list rows cannot include tracker check-in entries',
      ),
  };
}

/// Groups [entries] by local calendar day; unscheduled entries come last.
///
/// When [horizon] is set, every local day in the horizon is included even if
/// it has no tasks.
List<TaskListDaySection> groupTaskListEntries(
  List<TaskListEntry> entries, {
  TaskListHorizon? horizon,
}) {
  final sections = groupTimelineItems(
    entries.map(TaskTimelineItem.new).toList(),
    horizon: horizon,
  );
  return _fromTimelineSections(sections);
}

/// Flattens [sections] into scroll rows with optional edge loaders and add tile.
List<TaskListRow> flattenTaskListRows(
  List<TaskListDaySection> sections, {
  bool showPastLoader = false,
  bool showFutureLoader = false,
}) {
  final rows = flattenTimelineRows(
    _toTimelineSections(sections),
    showPastLoader: showPastLoader,
    showFutureLoader: showFutureLoader,
  );
  return rows.map(_fromTimelineRow).toList();
}
