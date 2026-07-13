import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/shared/services/quota_check_in_display.dart';

/// A materialized goal check-in moment from the API.
class GoalCheckIn {
  const GoalCheckIn({
    required this.id,
    required this.checkInAt,
    required this.goalType,
    required this.logged,
    this.displayAt,
    this.completed,
    this.countValue,
    this.pulseScore,
    this.periodStartAt,
    this.slotIndex,
    this.slotKind,
    this.failed = false,
  });

  final int id;
  final DateTime checkInAt;
  final DateTime? displayAt;
  final String goalType;
  final bool? completed;
  final num? countValue;
  final int? pulseScore;
  final bool logged;
  final DateTime? periodStartAt;
  final int? slotIndex;
  final String? slotKind;
  final bool failed;

  bool get isQuotaSlot =>
      checkInIsQuotaSlot(periodStartAt: periodStartAt, slotIndex: slotIndex);

  DateTime get timelineAt => checkInTimelineAt(
        checkInAt: checkInAt,
        displayAt: displayAt,
      );

  factory GoalCheckIn.fromJson(Map<String, dynamic> json) {
    return GoalCheckIn(
      id: json['id'] as int,
      checkInAt: DateTime.parse(json['check_in_at'] as String),
      displayAt: json['display_at'] == null
          ? null
          : DateTime.parse(json['display_at'] as String),
      goalType: json['goal_type'] as String? ?? GoalType.count,
      completed: json['completed'] as bool?,
      countValue: _numFromJson(json['count_value']),
      pulseScore: json['pulse_score'] as int?,
      logged: json['logged'] as bool? ?? false,
      periodStartAt: json['period_start_at'] == null
          ? null
          : DateTime.parse(json['period_start_at'] as String),
      slotIndex: json['slot_index'] as int?,
      slotKind: json['slot_kind'] as String?,
      failed: json['failed'] as bool? ?? false,
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
      other is GoalCheckIn &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          checkInAtMatches(checkInAt, other.checkInAt);

  static bool checkInAtMatches(DateTime a, DateTime b) =>
      a.toUtc().millisecondsSinceEpoch == b.toUtc().millisecondsSinceEpoch;

  @override
  int get hashCode => Object.hash(id, checkInAt.toUtc().millisecondsSinceEpoch);
}
