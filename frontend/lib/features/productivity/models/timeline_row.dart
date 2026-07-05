import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';

/// One row in the flattened productivity timeline list.
sealed class TimelineRow {}

class TimelineDateHeaderRow extends TimelineRow {
  TimelineDateHeaderRow({required this.day});

  final DateTime? day;
}

class TimelineTaskEntryRow extends TimelineRow {
  TimelineTaskEntryRow({
    required this.entry,
    required this.isFirstInDay,
    required this.isLastInDay,
  });

  final TaskListEntry entry;
  final bool isFirstInDay;
  final bool isLastInDay;
}

/// Stub row type for future event rendering in the overview timeline.
class TimelineEventEntryRow extends TimelineRow {
  TimelineEventEntryRow({
    required this.event,
    required this.occurrenceAt,
    required this.isFirstInDay,
    required this.isLastInDay,
    this.occurrenceId,
  });

  final Event event;
  final DateTime occurrenceAt;
  final bool isFirstInDay;
  final bool isLastInDay;
  final String? occurrenceId;
}

class TimelineTrackerCheckInRow extends TimelineRow {
  TimelineTrackerCheckInRow({
    required this.tracker,
    required this.checkIn,
    required this.isFirstInDay,
    required this.isLastInDay,
  });

  final Tracker tracker;
  final TrackerCheckIn checkIn;
  final bool isFirstInDay;
  final bool isLastInDay;
}

class TimelineLoadingRow extends TimelineRow {
  TimelineLoadingRow({required this.isPast});

  final bool isPast;
}

class TimelineAddTaskRow extends TimelineRow {
  TimelineAddTaskRow({required this.hasTasksAbove, this.day});

  final bool hasTasksAbove;
  final DateTime? day;
}
