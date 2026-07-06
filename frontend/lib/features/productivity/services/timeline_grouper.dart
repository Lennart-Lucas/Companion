import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/models/timeline_row.dart';
import 'package:frontend/features/productivity/services/task_bucket_summary.dart';
import 'package:frontend/features/productivity/services/task_list_builder.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

/// Items sharing one calendar day (null day = unscheduled).
class TimelineDaySection {
  const TimelineDaySection({
    required this.day,
    required this.items,
  });

  final DateTime? day;
  final List<TimelineSortableItem> items;
}

int _compareSortAt(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

List<TimelineSortableItem> _sortedItems(List<TimelineSortableItem> items) {
  final copy = [...items];
  copy.sort((a, b) => _compareSortAt(a.sortAt, b.sortAt));
  return copy;
}

/// Groups [items] by local calendar day; unscheduled items come last.
///
/// When [horizon] is set, every local day in the horizon is included even if
/// it has no items.
List<TimelineDaySection> groupTimelineItems(
  List<TimelineSortableItem> items, {
  TaskListHorizon? horizon,
}) {
  final byDay = <DateTime?, List<TimelineSortableItem>>{};

  for (final item in items) {
    final day = item.localDay;
    byDay.putIfAbsent(day, () => []).add(item);
  }

  final sections = <TimelineDaySection>[];

  if (horizon != null) {
    for (final day in horizon.localDays) {
      final normalized = normalizeTaskListCalendarDay(day);
      final sectionItems = byDay.entries
          .where(
            (entry) =>
                entry.key != null &&
                normalizeTaskListCalendarDay(entry.key!) == normalized,
          )
          .expand((entry) => entry.value)
          .toList();
      sections.add(
        TimelineDaySection(
          day: normalized,
          items: _sortedItems(sectionItems),
        ),
      );
    }
  } else {
    final datedDays = byDay.keys.whereType<DateTime>().toList()..sort();
    sections.addAll([
      for (final day in datedDays)
        TimelineDaySection(day: day, items: _sortedItems(byDay[day]!)),
    ]);
  }

  final unscheduled = byDay[null];
  if (unscheduled != null && unscheduled.isNotEmpty) {
    sections.add(
      TimelineDaySection(day: null, items: _sortedItems(unscheduled)),
    );
  }

  return sections;
}

TimelineRow _itemToRow(
  TimelineSortableItem item, {
  required bool isFirstInDay,
  required bool isLastInDay,
}) {
  return switch (item) {
    TaskTimelineItem(:final entry) => TimelineTaskEntryRow(
        entry: entry,
        isFirstInDay: isFirstInDay,
        isLastInDay: isLastInDay,
      ),
    EventTimelineItem(
      :final event,
      :final occurrenceAt,
      :final occurrenceId,
    ) =>
      TimelineEventEntryRow(
        event: event,
        occurrenceAt: occurrenceAt,
        occurrenceId: occurrenceId,
        isFirstInDay: isFirstInDay,
        isLastInDay: isLastInDay,
      ),
    TrackerTimelineItem(:final tracker, :final checkIn) =>
      TimelineTrackerCheckInRow(
        tracker: tracker,
        checkIn: checkIn,
        isFirstInDay: isFirstInDay,
        isLastInDay: isLastInDay,
      ),
  };
}

/// Flattens [sections] into scroll rows with optional edge loaders and add tile.
List<TimelineRow> flattenTimelineRows(
  List<TimelineDaySection> sections, {
  bool showPastLoader = false,
  bool showFutureLoader = false,
  bool showAddTaskRows = true,
  TaskBucketSummary? taskBucketSummary,
  DateTime? today,
}) {
  final rows = <TimelineRow>[];
  final todayDay = today != null ? normalizeTaskListCalendarDay(today) : null;

  if (showPastLoader) {
    rows.add(TimelineLoadingRow(isPast: true));
  }

  for (final section in sections) {
    rows.add(TimelineDateHeaderRow(day: section.day));
    if (taskBucketSummary != null &&
        todayDay != null &&
        section.day != null &&
        normalizeTaskListCalendarDay(section.day!) == todayDay) {
      rows.add(TimelineTaskBucketRow(summary: taskBucketSummary));
    }
    for (var i = 0; i < section.items.length; i++) {
      rows.add(
        _itemToRow(
          section.items[i],
          isFirstInDay: i == 0,
          isLastInDay: i == section.items.length - 1,
        ),
      );
    }
    if (showAddTaskRows) {
      rows.add(
        TimelineAddTaskRow(
          hasTasksAbove: section.items.isNotEmpty,
          day: section.day,
        ),
      );
    }
  }

  if (showFutureLoader) {
    rows.add(TimelineLoadingRow(isPast: false));
  }

  return rows;
}
