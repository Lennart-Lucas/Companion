import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

/// Whether a local calendar-day range overlaps a window (inclusive).
///
/// A null [rangeStart] means no lower bound; a null [rangeEnd] means no upper bound.
bool calendarDayRangeOverlaps(
  DateTime windowStart,
  DateTime windowEnd, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
}) {
  final normalizedWindowStart = normalizeTaskListCalendarDay(windowStart);
  final normalizedWindowEnd = normalizeTaskListCalendarDay(windowEnd);
  final normalizedRangeStart = rangeStart != null
      ? normalizeTaskListCalendarDay(rangeStart.toLocal())
      : null;
  final normalizedRangeEnd = rangeEnd != null
      ? normalizeTaskListCalendarDay(rangeEnd.toLocal())
      : null;

  if (normalizedRangeStart != null &&
      normalizedRangeStart.isAfter(normalizedWindowEnd)) {
    return false;
  }
  if (normalizedRangeEnd != null &&
      normalizedRangeEnd.isBefore(normalizedWindowStart)) {
    return false;
  }
  return true;
}

bool calendarDayRangeOverlapsHorizon(
  TaskListHorizon horizon, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
}) {
  return calendarDayRangeOverlaps(
    horizon.localFromDay,
    horizon.localToDay,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );
}

bool goalActiveInRange(Goal goal, DateTime rangeStart, DateTime rangeEnd) {
  return calendarDayRangeOverlaps(
    rangeStart,
    rangeEnd,
    rangeStart: goal.startDate,
    rangeEnd: goal.endDate,
  );
}

bool goalActiveInHorizon(Goal goal, TaskListHorizon horizon) {
  return calendarDayRangeOverlapsHorizon(
    horizon,
    rangeStart: goal.startDate,
    rangeEnd: goal.endDate,
  );
}

bool trackerActiveInRange(
  Tracker tracker,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  return calendarDayRangeOverlaps(
    rangeStart,
    rangeEnd,
    rangeStart: tracker.startDate,
    rangeEnd: tracker.endDate,
  );
}

bool trackerActiveInHorizon(Tracker tracker, TaskListHorizon horizon) {
  return calendarDayRangeOverlapsHorizon(
    horizon,
    rangeStart: tracker.startDate,
    rangeEnd: tracker.endDate,
  );
}

/// Projects use [Project.startDate] and [Project.deadline] as their active window.
bool projectActiveInRange(
  Project project,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  return calendarDayRangeOverlaps(
    rangeStart,
    rangeEnd,
    rangeStart: project.startDate,
    rangeEnd: project.deadline,
  );
}
