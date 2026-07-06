import 'package:frontend/features/productivity/models/goal_check_in.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

/// Calendar date for [dt] in local time.
DateTime quotaLocalDay(DateTime dt) => normalizeTaskListCalendarDay(dt.toLocal());

/// Display timestamp for a quota-mode check-in (active slots drift to today).
DateTime checkInDisplayAt(
  CheckInSlot checkIn, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = quotaLocalDay(current);

  if (checkIn.slotKind == CheckInSlotKind.active) {
    final spawnedDay = quotaLocalDay(checkIn.spawnedAt);
    final displayDay = spawnedDay.isBefore(today) ? today : spawnedDay;
    return _combineDayWithTime(displayDay, checkIn.spawnedAt);
  }

  if (checkIn.lockedAt != null) {
    return checkIn.lockedAt!;
  }
  return checkIn.checkInAt;
}

/// Resolves the timeline display time for a check-in.
DateTime resolvedCheckInDisplayAt(
  CheckInSlot checkIn, {
  required bool usesQuotaMode,
  DateTime? apiDisplayAt,
  DateTime? now,
}) {
  if (!usesQuotaMode) return checkIn.checkInAt;
  return apiDisplayAt ?? checkInDisplayAt(checkIn, now: now);
}

DateTime _combineDayWithTime(DateTime day, DateTime reference) {
  final localRef = reference.toLocal();
  return DateTime(
    day.year,
    day.month,
    day.day,
    localRef.hour,
    localRef.minute,
    localRef.second,
    localRef.millisecond,
    localRef.microsecond,
  );
}

abstract final class CheckInSlotKind {
  static const active = 'active';
  static const locked = 'locked';
  static const periodMiss = 'period_miss';
}

/// Common check-in slot fields shared by tracker and goal check-ins.
abstract class CheckInSlot {
  DateTime get checkInAt;
  DateTime get spawnedAt;
  DateTime? get lockedAt;
  String get slotKind;
  bool get logged;
}

extension TrackerCheckInDisplay on TrackerCheckIn {
  DateTime displayAtFor(Tracker tracker, {DateTime? now}) =>
      resolvedCheckInDisplayAt(
        this,
        usesQuotaMode: tracker.usesQuotaMode,
        apiDisplayAt: displayAt,
        now: now,
      );
}

extension GoalCheckInDisplay on GoalCheckIn {
  DateTime displayAtFor(Goal goal, {DateTime? now}) =>
      resolvedCheckInDisplayAt(
        this,
        usesQuotaMode: goal.usesQuotaMode,
        apiDisplayAt: displayAt,
        now: now,
      );
}
