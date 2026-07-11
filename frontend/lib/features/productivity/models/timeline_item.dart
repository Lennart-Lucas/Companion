import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';

/// One sortable item in the productivity overview timeline.
sealed class TimelineSortableItem {
  const TimelineSortableItem();

  DateTime? get localDay;
  DateTime? get sortAt;
  String get listKey;
}

/// Task or task occurrence row in the timeline.
class TaskTimelineItem extends TimelineSortableItem {
  const TaskTimelineItem(this.entry);

  final TaskListEntry entry;

  @override
  DateTime? get localDay => taskListEntryLocalDay(entry);

  @override
  DateTime? get sortAt =>
      entry.displayAt ?? entry.occurrenceAt ?? entry.task.plannedAt;

  @override
  String get listKey => entry.listKey;
}

/// Event row in the timeline (stub for future overview integration).
class EventTimelineItem extends TimelineSortableItem {
  const EventTimelineItem({
    required this.event,
    required this.occurrenceAt,
    this.occurrenceId,
  });

  final Event event;
  final DateTime occurrenceAt;
  final String? occurrenceId;

  @override
  DateTime? get localDay {
    final local = occurrenceAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @override
  DateTime? get sortAt => occurrenceAt;

  @override
  String get listKey {
    if (occurrenceId != null) {
      return '${event.id}:$occurrenceId';
    }
    return '${event.id}:${occurrenceAt.toUtc().toIso8601String()}';
  }
}

/// Tracker check-in moment in the overview timeline.
class TrackerTimelineItem extends TimelineSortableItem {
  const TrackerTimelineItem({
    required this.tracker,
    required this.checkIn,
  });

  final Tracker tracker;
  final TrackerCheckIn checkIn;

  @override
  DateTime? get localDay =>
      normalizeTaskListCalendarDay(checkIn.checkInAt.toLocal());

  @override
  DateTime? get sortAt => checkIn.checkInAt;

  @override
  String get listKey => 'tracker:${tracker.id}:${checkIn.id}';
}

/// Goal check-in moment in the overview timeline.
class GoalTimelineItem extends TimelineSortableItem {
  const GoalTimelineItem({
    required this.goal,
    required this.checkIn,
  });

  final Goal goal;
  final GoalCheckIn checkIn;

  @override
  DateTime? get localDay =>
      normalizeTaskListCalendarDay(checkIn.checkInAt.toLocal());

  @override
  DateTime? get sortAt => checkIn.checkInAt;

  @override
  String get listKey => 'goal:${goal.id}:${checkIn.id}';
}
