import 'package:frontend/core/formatting/week_calendar.dart';

/// Whether [checkIn] is a quota slot (has period metadata).
bool checkInIsQuotaSlot({
  DateTime? periodStartAt,
  int? slotIndex,
}) =>
    periodStartAt != null && slotIndex != null;

/// Effective timeline day for a check-in (API display_at or fallback).
DateTime checkInTimelineAt({
  required DateTime checkInAt,
  DateTime? displayAt,
}) =>
    normalizeTaskListCalendarDay((displayAt ?? checkInAt).toLocal());

/// Client-side fallback when [displayAt] is absent (mirrors backend drift rules).
DateTime computeQuotaCheckInDisplayAt({
  required DateTime checkInAt,
  required DateTime? spawnedAt,
  required DateTime? lockedAt,
  required String? slotKind,
  required DateTime periodEndAt,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  if (slotKind == 'failed') {
    return periodEndAt;
  }
  if (slotKind == 'locked' && lockedAt != null) {
    return lockedAt;
  }
  final spawned = spawnedAt ?? checkInAt;
  final today = normalizeTaskListCalendarDay(current);
  final spawnedDay = normalizeTaskListCalendarDay(spawned.toLocal());
  final periodEndDay = normalizeTaskListCalendarDay(periodEndAt.toLocal());
  final displayDay = spawnedDay.isBefore(today) ? today : spawnedDay;
  if (displayDay.isAfter(periodEndDay)) {
    return periodEndAt;
  }
  return DateTime(
    displayDay.year,
    displayDay.month,
    displayDay.day,
    spawned.hour,
    spawned.minute,
    spawned.second,
  );
}

bool quotaCheckInFailed({required String? slotKind, bool failed = false}) =>
    failed || slotKind == 'failed';
