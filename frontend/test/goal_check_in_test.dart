import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';

void main() {
  test('GoalCheckIn.fromJson parses logged count check-in', () {
    final checkIn = GoalCheckIn.fromJson({
      'id': 7,
      'check_in_at': '2026-06-10T09:00:00Z',
      'goal_type': 'count',
      'count_value': '4',
      'logged': true,
    });

    expect(checkIn.id, 7);
    expect(checkIn.goalType, 'count');
    expect(checkIn.countValue, 4);
    expect(checkIn.logged, isTrue);
  });

  test('GoalCheckIn.fromJson parses task check-in', () {
    final checkIn = GoalCheckIn.fromJson({
      'id': 2,
      'check_in_at': '2026-06-10T09:00:00Z',
      'goal_type': 'task',
      'completed': true,
      'logged': true,
    });

    expect(checkIn.completed, isTrue);
    expect(checkIn.logged, isTrue);
  });
}
