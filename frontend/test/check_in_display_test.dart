import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_schedule.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/check_in_display.dart';

Tracker _fixedScheduleTracker() => Tracker(
      id: '1',
      name: 'Habit',
      startDate: DateTime(2026, 1, 1),
      checkInType: TrackerCheckInType.task,
    );

Tracker _quotaTracker() => Tracker(
      id: '2',
      name: 'Gym',
      startDate: DateTime(2026, 1, 1),
      checkInType: TrackerCheckInType.task,
      checkInMode: CheckInMode.timesPerPeriod,
      quotaTimes: 3,
      quotaPeriodInterval: 1,
      quotaPeriodUnit: QuotaPeriodUnit.weeks,
    );

void main() {
  group('checkInDisplayAt', () {
    test('active quota slot drifts to today when spawned in the past', () {
      final spawned = DateTime(2026, 1, 5, 9);
      final checkIn = TrackerCheckIn(
        id: 1,
        checkInAt: spawned,
        checkInType: 'task',
        logged: false,
        skipped: false,
        spawnedAt: spawned,
        slotKind: CheckInSlotKind.active,
      );
      final display = checkIn.displayAtFor(
        _quotaTracker(),
        now: DateTime(2026, 1, 10, 12),
      );
      expect(display.year, 2026);
      expect(display.month, 1);
      expect(display.day, 10);
    });

    test('fixed-schedule check-in stays on scheduled day', () {
      final scheduled = DateTime(2026, 1, 5, 9);
      final checkIn = TrackerCheckIn(
        id: 1,
        checkInAt: scheduled,
        checkInType: 'task',
        logged: false,
        skipped: false,
        spawnedAt: scheduled,
        slotKind: CheckInSlotKind.active,
      );
      final display = checkIn.displayAtFor(
        _fixedScheduleTracker(),
        now: DateTime(2026, 1, 10, 12),
      );
      expect(display.day, 5);
    });

    test('locked quota slot uses locked day', () {      final spawned = DateTime(2026, 1, 5, 9);
      final locked = DateTime(2026, 1, 7, 9);
      final checkIn = TrackerCheckIn(
        id: 1,
        checkInAt: locked,
        checkInType: 'task',
        logged: true,
        skipped: false,
        spawnedAt: spawned,
        lockedAt: locked,
        slotKind: CheckInSlotKind.locked,
        completed: true,
      );
      final display = checkIn.displayAtFor(
        _quotaTracker(),
        now: DateTime(2026, 1, 10, 12),
      );      expect(display.day, 7);
    });
  });
}
