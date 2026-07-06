import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/task_list_filter.dart';

void main() {
  TaskListEntry entryWithStatus(String status) {
    final task = Task(id: '1', name: 'Task', status: status);
    return TaskListEntry(
      task: task,
      status: status,
      priority: 'medium',
      subtasks: const [],
      isVirtual: true,
    );
  }

  group('filterVisibleTaskListEntries', () {
    test('hides completed entries by default', () {
      final entries = [
        entryWithStatus('pending'),
        entryWithStatus('completed'),
        entryWithStatus('in_progress'),
      ];

      final filtered = filterVisibleTaskListEntries(entries);

      expect(filtered.map((e) => e.status), ['pending', 'in_progress']);
    });

    test('keeps completed entries when hideCompleted is false', () {
      final entries = [
        entryWithStatus('pending'),
        entryWithStatus('completed'),
      ];

      final filtered = filterVisibleTaskListEntries(
        entries,
        hideCompleted: false,
      );

      expect(filtered.length, 2);
    });
  });

  group('filterVisibleTimelineItems', () {
    test('hides completed tasks and succeeded tracker check-ins', () {
      final now = DateTime(2026, 6, 10, 12);
      final tracker = Tracker(
        id: 't1',
        name: 'Habit',
        checkInType: TrackerCheckInType.task,
        startDate: DateTime(2026, 1, 1),
      );
      final succeededCheckIn = TrackerCheckIn(
        id: 1,
        checkInAt: DateTime(2026, 6, 10, 8),
        checkInType: TrackerCheckInType.task,
        logged: true,
        skipped: false,
        completed: true,
      );
      final pendingCheckIn = TrackerCheckIn(
        id: 2,
        checkInAt: DateTime(2026, 6, 10, 18),
        checkInType: TrackerCheckInType.task,
        logged: false,
        skipped: false,
        completed: false,
      );

      final items = <TimelineSortableItem>[
        TaskTimelineItem(entryWithStatus('completed')),
        TaskTimelineItem(entryWithStatus('pending')),
        TrackerTimelineItem(tracker: tracker, checkIn: succeededCheckIn),
        TrackerTimelineItem(tracker: tracker, checkIn: pendingCheckIn),
      ];

      final filtered = filterVisibleTimelineItems(items, now: now);

      expect(filtered.length, 2);
      expect(filtered[0], isA<TaskTimelineItem>());
      expect((filtered[0] as TaskTimelineItem).entry.status, 'pending');
      expect(filtered[1], isA<TrackerTimelineItem>());
      expect((filtered[1] as TrackerTimelineItem).checkIn.id, 2);
    });
  });
}
