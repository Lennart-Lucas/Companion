import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/check_in_display.dart';

/// A materialized tracker check-in moment from the API.
class TrackerCheckIn implements CheckInSlot {
  const TrackerCheckIn({
    required this.id,
    required this.checkInAt,
    required this.checkInType,
    required this.logged,
    required this.skipped,
    required this.spawnedAt,
    required this.slotKind,
    this.completed,
    this.countValue,
    this.valueSeconds,
    this.timerStartedAt,
    this.lockedAt,
    this.displayAt,
  });

  final int id;
  @override
  final DateTime checkInAt;
  final String checkInType;
  final bool? completed;
  final num? countValue;
  final int? valueSeconds;
  final DateTime? timerStartedAt;
  @override
  final bool logged;
  final bool skipped;
  @override
  final DateTime spawnedAt;
  @override
  final DateTime? lockedAt;
  @override
  final String slotKind;
  final DateTime? displayAt;

  DateTime get resolvedDisplayAt => displayAt ?? checkInAt;

  factory TrackerCheckIn.fromJson(Map<String, dynamic> json) {
    final spawnedAt = DateTime.parse(
      (json['spawned_at'] ?? json['check_in_at']) as String,
    );
    return TrackerCheckIn(
      id: json['id'] as int,
      checkInAt: DateTime.parse(json['check_in_at'] as String),
      checkInType: json['check_in_type'] as String,
      completed: json['completed'] as bool?,
      countValue: _numFromJson(json['count_value']),
      valueSeconds: json['value_seconds'] as int?,
      timerStartedAt: json['timer_started_at'] == null
          ? null
          : DateTime.parse(json['timer_started_at'] as String),
      logged: json['logged'] as bool? ?? false,
      skipped: json['skipped'] as bool? ?? false,
      spawnedAt: spawnedAt,
      lockedAt: json['locked_at'] == null
          ? null
          : DateTime.parse(json['locked_at'] as String),
      slotKind: json['slot_kind'] as String? ?? CheckInSlotKind.active,
      displayAt: json['display_at'] == null
          ? null
          : DateTime.parse(json['display_at'] as String),
    );
  }

  static num? _numFromJson(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String && value.isNotEmpty) {
      return num.tryParse(value);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackerCheckIn &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          trackerIdMatches(checkInAt, other.checkInAt);

  static bool trackerIdMatches(DateTime a, DateTime b) =>
      a.toUtc().millisecondsSinceEpoch == b.toUtc().millisecondsSinceEpoch;

  @override
  int get hashCode => Object.hash(id, checkInAt.toUtc().millisecondsSinceEpoch);
}

/// Total elapsed seconds including a running timer session.
int trackerCheckInElapsedSeconds(TrackerCheckIn checkIn, DateTime now) {
  final base = checkIn.valueSeconds ?? 0;
  final started = checkIn.timerStartedAt;
  if (started == null) return base;

  final delta = now.difference(started.toUtc()).inSeconds;
  return base + (delta > 0 ? delta : 0);
}

bool isTrackerTargetReached(Tracker tracker, TrackerCheckIn checkIn) {
  if (checkIn.skipped || !checkIn.logged) return false;

  final build = tracker.habitDirection == TrackerHabitDirection.build;

  switch (tracker.checkInType) {
    case TrackerCheckInType.task:
      final completed = checkIn.completed;
      if (completed == null) return false;
      return build ? completed : !completed;
    case TrackerCheckInType.count:
      final target = tracker.target;
      final value = checkIn.countValue;
      if (target == null || value == null) return false;
      return build ? value >= target : value <= target;
    case TrackerCheckInType.duration:
      final target = tracker.target?.toInt();
      final value = checkIn.valueSeconds;
      if (target == null || value == null) return false;
      return build ? value >= target : value <= target;
    default:
      return false;
  }
}
