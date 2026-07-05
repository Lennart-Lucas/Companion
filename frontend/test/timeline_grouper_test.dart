import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/models/timeline_row.dart';
import 'package:frontend/features/productivity/services/task_list_builder.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';
import 'package:frontend/features/productivity/services/timeline_grouper.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

TaskTimelineItem _taskItem({
  required String id,
  required String name,
  DateTime? occurrenceAt,
}) {
  final task = Task(
    id: id,
    name: name,
    plannedAt: occurrenceAt,
  );
  return TaskTimelineItem(
    applyTaskListDisplayRules(
      TaskListEntry(
        task: task,
        occurrenceAt: occurrenceAt,
        status: 'pending',
        priority: 'medium',
        subtasks: const [],
        isVirtual: true,
      ),
      now: occurrenceAt ?? DateTime(2026, 6, 7),
    ),
  );
}

void main() {
  group('groupTimelineItems', () {
    test('groups items by local calendar day and sorts within day', () {
      final day1 = DateTime(2026, 6, 7, 9);
      final day2 = DateTime(2026, 6, 8, 14);
      final items = [
        _taskItem(id: 'b', name: 'B', occurrenceAt: day2),
        _taskItem(id: 'a', name: 'A', occurrenceAt: day1),
        _taskItem(
          id: 'a2',
          name: 'A2',
          occurrenceAt: day1.add(const Duration(hours: 2)),
        ),
      ];

      final sections = groupTimelineItems(items);

      expect(sections.length, 2);
      expect(sections[0].day, taskListEntryLocalDay(items[2].entry));
      expect(
        sections[0].items.map((item) => (item as TaskTimelineItem).entry.task.name),
        ['A', 'A2'],
      );
      expect(sections[1].day, taskListEntryLocalDay(items[0].entry));
      expect(
        (sections[1].items.single as TaskTimelineItem).entry.task.name,
        'B',
      );
    });

    test('includes every day in horizon even when empty', () {
      final horizon = TaskListHorizon.forLocalDays(
        DateTime(2026, 6, 5),
        DateTime(2026, 6, 7),
      );
      final items = [
        _taskItem(id: '1', name: 'Only', occurrenceAt: DateTime(2026, 6, 6)),
      ];

      final sections = groupTimelineItems(items, horizon: horizon);

      expect(sections.length, 3);
      expect(sections[0].day, DateTime(2026, 6, 5));
      expect(sections[0].items, isEmpty);
      expect(sections[1].items.single, isA<TaskTimelineItem>());
      expect(sections[2].day, DateTime(2026, 6, 7));
      expect(sections[2].items, isEmpty);
    });
  });

  group('flattenTimelineRows', () {
    test('maps task items to timeline task rows', () {
      final day = DateTime(2026, 6, 7);
      final sections = [
        TimelineDaySection(
          day: day,
          items: [
            _taskItem(id: '1', name: 'One', occurrenceAt: day),
            _taskItem(
              id: '2',
              name: 'Two',
              occurrenceAt: day.add(const Duration(hours: 1)),
            ),
          ],
        ),
      ];

      final rows = flattenTimelineRows(sections);

      expect(rows[0], isA<TimelineDateHeaderRow>());
      expect(rows[1], isA<TimelineTaskEntryRow>());
      expect(rows[2], isA<TimelineTaskEntryRow>());
      expect(rows[3], isA<TimelineAddTaskRow>());

      final first = rows[1] as TimelineTaskEntryRow;
      final last = rows[2] as TimelineTaskEntryRow;
      expect(first.isFirstInDay, isTrue);
      expect(last.isLastInDay, isTrue);
    });

    test('interleaves tasks and tracker check-ins by sort time', () {
      final day = DateTime(2026, 6, 7);
      final tracker = Tracker(
        id: 't1',
        name: 'Water',
        startDate: day,
      );
      final items = [
        TrackerTimelineItem(
          tracker: tracker,
          checkIn: TrackerCheckIn(
            id: 2,
            checkInAt: day.add(const Duration(hours: 14)),
            checkInType: TrackerCheckInType.task,
            logged: true,
            skipped: false,
            completed: true,
          ),
        ),
        _taskItem(
          id: '1',
          name: 'Morning task',
          occurrenceAt: day.add(const Duration(hours: 9)),
        ),
      ];

      final sections = groupTimelineItems(items);
      final rows = flattenTimelineRows(sections);
      final contentRows = rows
          .where(
            (row) =>
                row is TimelineTaskEntryRow ||
                row is TimelineTrackerCheckInRow,
          )
          .toList();

      expect(contentRows[0], isA<TimelineTaskEntryRow>());
      expect(contentRows[1], isA<TimelineTrackerCheckInRow>());
    });
  });
}
