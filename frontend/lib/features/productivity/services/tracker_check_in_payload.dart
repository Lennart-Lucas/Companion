import 'package:frontend/features/productivity/models/productivity_record.dart';

/// PATCH/POST body for logging a tracker check-in moment.
Map<String, dynamic> trackerCheckInLogPayload({
  required String checkInType,
  bool? completed,
  num? countValue,
  int? valueSeconds,
  DateTime? timerStartedAt,
  bool skipped = false,
}) {
  if (skipped) {
    return {'skipped': true};
  }

  if (timerStartedAt != null) {
    return {'timer_started_at': timerStartedAt.toUtc().toIso8601String()};
  }

  return switch (checkInType) {
    TrackerCheckInType.task => {'completed': completed ?? false},
    TrackerCheckInType.count => {'count_value': countValue ?? 0},
    TrackerCheckInType.duration => {'value_seconds': valueSeconds ?? 0},
    _ => throw ArgumentError('Unsupported check-in type: $checkInType'),
  };
}

/// POST body for creating an ad-hoc logged check-in.
Map<String, dynamic> trackerCheckInCreatePayload({
  required DateTime checkInAt,
  required String checkInType,
  bool? completed,
  num? countValue,
  int? valueSeconds,
  bool skipped = false,
}) {
  return {
    'check_in_at': checkInAt.toUtc().toIso8601String(),
    ...trackerCheckInLogPayload(
      checkInType: checkInType,
      completed: completed,
      countValue: countValue,
      valueSeconds: valueSeconds,
      skipped: skipped,
    ),
  };
}
