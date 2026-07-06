import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';
import 'package:frontend/features/productivity/services/timeline_filter.dart';

TaskTimelineItem _taskItem({required String status}) {
  final now = DateTime(2026, 6, 7, 12);
  return TaskTimelineItem(
    applyTaskListDisplayRules(
      TaskListEntry(
        task: Task(
          id: 't1',
          name: 'Task',
          plannedAt: now,
        ),
        occurrenceAt: now,
        status: status,
        priority: 'medium',
        subtasks: const [],
        isVirtual: true,
      ),
      now: now,
    ),
  );
}

TrackerTimelineItem _trackerItem({
  required TrackerCheckIn checkIn,
}) {
  return TrackerTimelineItem(
    tracker: Tracker(
      id: 'tr1',
      name: 'Habit',
      startDate: DateTime(2026, 1, 1),
      checkInType: TrackerCheckInType.task,
      habitDirection: TrackerHabitDirection.build,
    ),
    checkIn: checkIn,
  );
}

TrackerCheckIn _checkIn({
  required int id,
  required DateTime checkInAt,
  bool logged = false,
  bool skipped = false,
  bool? completed,
  String slotKind = 'active',
}) {
  return TrackerCheckIn(
    id: id,
    checkInAt: checkInAt,
    checkInType: TrackerCheckInType.task,
    logged: logged,
    skipped: skipped,
    spawnedAt: checkInAt,
    slotKind: slotKind,
    completed: completed,
    lockedAt: logged ? checkInAt : null,
  );
}

void main() {
  final now = DateTime(2026, 6, 7, 18);

  group('timelineItemIsFinished', () {
    test('pending task is not finished', () {
      expect(
        timelineItemIsFinished(_taskItem(status: 'pending'), now: now),
        isFalse,
      );
    });

    test('completed and cancelled tasks are finished', () {
      expect(
        timelineItemIsFinished(_taskItem(status: 'completed'), now: now),
        isTrue,
      );
      expect(
        timelineItemIsFinished(_taskItem(status: 'cancelled'), now: now),
        isTrue,
      );
    });

    test('pending tracker check-in is not finished', () {
      final item = _trackerItem(
        checkIn: _checkIn(
          id: 1,
          checkInAt: DateTime(2026, 6, 7, 9),
        ),
      );

      expect(timelineItemIsFinished(item, now: now), isFalse);
    });

    test('succeeded and skipped tracker check-ins are finished', () {
      final succeeded = _trackerItem(
        checkIn: _checkIn(
          id: 1,
          checkInAt: DateTime(2026, 6, 7, 9),
          logged: true,
          completed: true,
          slotKind: 'locked',
        ),
      );
      final skipped = _trackerItem(
        checkIn: _checkIn(
          id: 2,
          checkInAt: DateTime(2026, 6, 7, 10),
          skipped: true,
          logged: true,
          slotKind: 'locked',
        ),
      );

      expect(timelineItemIsFinished(succeeded, now: now), isTrue);
      expect(timelineItemIsFinished(skipped, now: now), isTrue);
    });
  });

  group('applyTimelineFilter', () {
    test('showAll keeps every item', () {
      final items = [
        _taskItem(status: 'pending'),
        _taskItem(status: 'completed'),
      ];

      expect(
        applyTimelineFilter(items, ProductivityTimelineFilter.showAll, now: now),
        items,
      );
    });

    test('activeOnly hides finished items', () {
      final pending = _taskItem(status: 'pending');
      final completed = _taskItem(status: 'completed');
      final cancelled = _taskItem(status: 'cancelled');

      final filtered = applyTimelineFilter(
        [pending, completed, cancelled],
        ProductivityTimelineFilter.activeOnly,
        now: now,
      );

      expect(filtered, [pending]);
    });
  });
}
