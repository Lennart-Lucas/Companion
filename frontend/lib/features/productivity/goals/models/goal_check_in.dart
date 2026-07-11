import 'package:frontend/features/productivity/goals/models/goal.dart';


/// A materialized goal check-in moment from the API.
class GoalCheckIn {
  const GoalCheckIn({
    required this.id,
    required this.checkInAt,
    required this.goalType,
    required this.logged,
    this.completed,
    this.countValue,
    this.pulseScore,
  });

  final int id;
  final DateTime checkInAt;
  final String goalType;
  final bool? completed;
  final num? countValue;
  final int? pulseScore;
  final bool logged;

  factory GoalCheckIn.fromJson(Map<String, dynamic> json) {
    return GoalCheckIn(
      id: json['id'] as int,
      checkInAt: DateTime.parse(json['check_in_at'] as String),
      goalType: json['goal_type'] as String? ?? GoalType.count,
      completed: json['completed'] as bool?,
      countValue: _numFromJson(json['count_value']),
      pulseScore: json['pulse_score'] as int?,
      logged: json['logged'] as bool? ?? false,
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
