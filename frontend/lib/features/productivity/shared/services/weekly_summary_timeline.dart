import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/features/productivity/shared/models/timeline_item.dart';
import 'package:frontend/features/productivity/shared/models/timeline_row.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_display.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';

bool isWeeklySummaryDay(DateTime day) => taskListDayIsSunday(day);

bool shouldShowWeeklySummary(DateTime sunday, DateTime today) {
  final normalizedSunday = normalizeTaskListCalendarDay(sunday);
  final normalizedToday = normalizeTaskListCalendarDay(today);
  if (!normalizedSunday.isAfter(normalizedToday)) return true;
  // Current week's closing Sunday is available before that day arrives.
  return normalizedSunday == taskListWeekEnd(taskListWeekStart(normalizedToday));
}

bool weekIntersectsHorizon(DateTime weekStart, TaskListHorizon horizon) {
  final weekEnd = taskListWeekEnd(weekStart);
  final horizonStart = horizon.localFromDay;
  final horizonEnd = horizon.localToDay;
  return !weekStart.isAfter(horizonEnd) && !weekEnd.isBefore(horizonStart);
}

bool _dayInWeek(DateTime day, DateTime weekStart, DateTime weekEnd) {
  final normalized = normalizeTaskListCalendarDay(day);
  return !normalized.isBefore(weekStart) && !normalized.isAfter(weekEnd);
}

bool taskEntryInWeek(TaskListEntry entry, DateTime weekStart, DateTime weekEnd) {
  final displayAt = entry.displayAt ?? taskListEntryScheduledAt(entry);
  if (displayAt != null && _dayInWeek(displayAt, weekStart, weekEnd)) {
    return true;
  }
  if (entry.status == 'completed') {
    final resolved = entry.resolvedAt ?? entry.displayAt ?? entry.task.updatedAt;
    if (resolved != null && _dayInWeek(resolved, weekStart, weekEnd)) {
      return true;
    }
  }
  return false;
}

bool _checkInInWeek(DateTime checkInAt, DateTime weekStart, DateTime weekEnd) {
  return _dayInWeek(checkInAt, weekStart, weekEnd);
}

WeeklySummaryPreview computeWeeklySummaryPreview({
  required DateTime weekStart,
  required List<TaskListEntry> taskEntries,
  required List<TrackerTimelineItem> trackerItems,
  required List<GoalTimelineItem> goalItems,
}) {
  final normalizedWeekStart = normalizeTaskListCalendarDay(weekStart);
  final weekEnd = taskListWeekEnd(normalizedWeekStart);

  var tasksCompleted = 0;
  for (final entry in taskEntries) {
    if (entry.status != 'completed') continue;
    final resolved = entry.resolvedAt ?? entry.displayAt ?? entry.task.updatedAt;
    if (resolved != null && _dayInWeek(resolved, normalizedWeekStart, weekEnd)) {
      tasksCompleted++;
    }
  }

  var trackerSucceeded = 0;
  var trackerMissed = 0;
  for (final item in trackerItems) {
    if (!_checkInInWeek(
      item.checkIn.checkInAt,
      normalizedWeekStart,
      weekEnd,
    )) {
      continue;
    }
    final outcome = classifyTrackerCheckIn(
      item.tracker,
      item.checkIn,
      now: item.checkIn.checkInAt,
    );
    switch (outcome) {
      case TrackerCheckInOutcome.succeeded:
        trackerSucceeded++;
      case TrackerCheckInOutcome.missed:
        trackerMissed++;
      case TrackerCheckInOutcome.skipped:
      case TrackerCheckInOutcome.pending:
        break;
    }
  }

  final trackerDenominator = trackerSucceeded + trackerMissed;
  final trackerSuccessPercent = trackerDenominator == 0
      ? null
      : trackerSucceeded / trackerDenominator;

  return WeeklySummaryPreview(
    tasksCompleted: tasksCompleted,
    trackerSuccessPercent: trackerSuccessPercent,
  );
}

bool _isTimelineEntryRow(TimelineRow row) {
  return row is TimelineTaskEntryRow ||
      row is TimelineTrackerCheckInRow ||
      row is TimelineGoalCheckInRow ||
      row is TimelineEventEntryRow;
}

int _indexAfterDayHeaderInsertPoint(List<TimelineRow> rows, int headerIndex) {
  var insertAt = headerIndex + 1;
  while (insertAt < rows.length && rows[insertAt] is TimelineTodayBucketsRow) {
    insertAt++;
  }
  return insertAt;
}

TimelineRow _entryRowWithIsFirst(TimelineRow row, {required bool isFirstInDay}) {
  return switch (row) {
    TimelineTaskEntryRow(
      :final entry,
      :final isLastInDay,
    ) =>
      TimelineTaskEntryRow(
        entry: entry,
        isFirstInDay: isFirstInDay,
        isLastInDay: isLastInDay,
      ),
    TimelineTrackerCheckInRow(
      :final tracker,
      :final checkIn,
      :final isLastInDay,
    ) =>
      TimelineTrackerCheckInRow(
        tracker: tracker,
        checkIn: checkIn,
        isFirstInDay: isFirstInDay,
        isLastInDay: isLastInDay,
      ),
    TimelineGoalCheckInRow(
      :final goal,
      :final checkIn,
      :final isLastInDay,
    ) =>
      TimelineGoalCheckInRow(
        goal: goal,
        checkIn: checkIn,
        isFirstInDay: isFirstInDay,
        isLastInDay: isLastInDay,
      ),
    TimelineEventEntryRow(
      :final event,
      :final occurrenceAt,
      :final occurrenceId,
      :final isLastInDay,
    ) =>
      TimelineEventEntryRow(
        event: event,
        occurrenceAt: occurrenceAt,
        occurrenceId: occurrenceId,
        isFirstInDay: isFirstInDay,
        isLastInDay: isLastInDay,
      ),
    _ => row,
  };
}

void _patchWeeklySummaryTimelineConnections(
  List<TimelineRow> rows,
  int start,
  int end,
) {
  var summaryIndex = -1;
  TimelineWeeklySummaryRow? summary;
  final entryIndices = <int>[];

  for (var i = start; i < end; i++) {
    final row = rows[i];
    if (row is TimelineWeeklySummaryRow) {
      summary = row;
      summaryIndex = i;
    } else if (_isTimelineEntryRow(row)) {
      entryIndices.add(i);
    }
  }

  if (summary == null || summaryIndex < 0) return;

  final hasEntries = entryIndices.isNotEmpty;
  rows[summaryIndex] = TimelineWeeklySummaryRow(
    weekStart: summary.weekStart,
    preview: summary.preview,
    isFirstInDay: true,
    isLastInDay: false,
  );

  if (hasEntries) {
    final firstEntryIndex = entryIndices.first;
    rows[firstEntryIndex] = _entryRowWithIsFirst(
      rows[firstEntryIndex],
      isFirstInDay: false,
    );
  }

  for (var i = start; i < end; i++) {
    final row = rows[i];
    if (row is TimelineAddTaskRow) {
      rows[i] = TimelineAddTaskRow(
        hasTasksAbove: true,
        day: row.day,
      );
    }
  }
}

List<TimelineRow> _patchAllWeeklySummaryTimelineConnections(
  List<TimelineRow> rows,
) {
  for (var i = 0; i < rows.length; i++) {
    if (rows[i] is! TimelineDateHeaderRow) continue;

    var end = i + 1;
    while (end < rows.length &&
        rows[end] is! TimelineDateHeaderRow &&
        rows[end] is! TimelineLoadingRow) {
      end++;
    }
    _patchWeeklySummaryTimelineConnections(rows, i + 1, end);
  }
  return rows;
}

List<TimelineRow> applyWeeklySummaryRows({
  required List<TimelineRow> rows,
  required DateTime today,
  required TaskListHorizon horizon,
  WeeklySummaryPreview Function(DateTime weekStart)? previewForWeek,
}) {
  final copy = [...rows];

  for (var i = 0; i < copy.length; i++) {
    final row = copy[i];
    if (row is! TimelineDateHeaderRow || row.day == null) continue;
    final day = normalizeTaskListCalendarDay(row.day!);
    if (!isWeeklySummaryDay(day)) continue;
    if (!shouldShowWeeklySummary(day, today)) continue;

    final weekStart = taskListWeekStart(day);
    if (!weekIntersectsHorizon(weekStart, horizon)) continue;

    final insertAt = _indexAfterDayHeaderInsertPoint(copy, i);
    final preview = previewForWeek?.call(weekStart) ?? WeeklySummaryPreview.empty;
    final summaryRow = TimelineWeeklySummaryRow(
      weekStart: weekStart,
      preview: preview,
    );

    if (insertAt < copy.length && copy[insertAt] is TimelineWeeklySummaryRow) {
      copy[insertAt] = summaryRow;
    } else {
      copy.insert(insertAt, summaryRow);
      i++;
    }
  }

  return _patchAllWeeklySummaryTimelineConnections(copy);
}
