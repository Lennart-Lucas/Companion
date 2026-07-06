import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/check_in_display.dart';

/// A materialized goal check-in moment from the API.
class GoalCheckIn implements CheckInSlot {
  const GoalCheckIn({
    required this.id,
    required this.checkInAt,
    required this.goalType,
    required this.logged,
    required this.spawnedAt,
    required this.slotKind,
    this.completed,
    this.countValue,
    this.pulseScore,
    this.lockedAt,
    this.displayAt,
  });

  final int id;
  @override
  final DateTime checkInAt;
  final String goalType;
  final bool? completed;
  final num? countValue;
  final int? pulseScore;
  @override
  final bool logged;
  @override
  final DateTime spawnedAt;
  @override
  final DateTime? lockedAt;
  @override
  final String slotKind;
  final DateTime? displayAt;

  DateTime get resolvedDisplayAt => displayAt ?? checkInAt;

  factory GoalCheckIn.fromJson(Map<String, dynamic> json) {
    final spawnedAt = DateTime.parse(
      (json['spawned_at'] ?? json['check_in_at']) as String,
    );
    return GoalCheckIn(
      id: json['id'] as int,
      checkInAt: DateTime.parse(json['check_in_at'] as String),
      goalType: json['goal_type'] as String? ?? GoalType.count,
      completed: json['completed'] as bool?,
      countValue: _numFromJson(json['count_value']),
      pulseScore: json['pulse_score'] as int?,
      logged: json['logged'] as bool? ?? false,
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
}
