import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/goal_check_in.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/goal_stats.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

Goal _goal({
  String goalType = GoalType.count,
  num target = 12,
  String direction = GoalDirection.increasing,
}) =>
    Goal(
      id: '1',
      name: 'Books',
      goalType: goalType,
      target: target,
      unit: 'books',
      direction: direction,
      startDate: DateTime.utc(2026, 1, 1),
    );

GoalCheckIn _checkIn({
  required DateTime at,
  bool logged = false,
  num? countValue,
  bool? completed,
  int? pulseScore,
  String goalType = GoalType.count,
}) =>
    GoalCheckIn(
      id: at.millisecondsSinceEpoch,
      checkInAt: at,
      goalType: goalType,
      logged: logged,
      countValue: countValue,
      completed: completed,
      pulseScore: pulseScore,
    );

void main() {
  group('classifyGoalCheckIn', () {
    test('returns logged when check-in is logged', () {
      final checkIn = _checkIn(
        at: DateTime.utc(2026, 6, 10),
        logged: true,
        countValue: 2,
      );

      expect(classifyGoalCheckIn(checkIn), GoalCheckInOutcome.logged);
    });

    test('returns pending when check-in is not logged', () {
      final checkIn = _checkIn(at: DateTime.utc(2026, 6, 9));

      expect(classifyGoalCheckIn(checkIn), GoalCheckInOutcome.pending);
    });
  });

  group('computeGoalProgress', () {
    test('sums count values toward increasing target', () {
      final goal = _goal(target: 10);
      final checkIns = [
        _checkIn(
          at: DateTime.utc(2026, 6, 1),
          logged: true,
          countValue: 3,
        ),
        _checkIn(
          at: DateTime.utc(2026, 6, 2),
          logged: true,
          countValue: 4,
        ),
      ];

      expect(computeGoalProgress(goal, checkIns), 0.7);
    });

    test('counts completed task periods toward target', () {
      final goal = _goal(goalType: GoalType.task, target: 4);
      final checkIns = [
        _checkIn(
          at: DateTime.utc(2026, 6, 1),
          goalType: GoalType.task,
          logged: true,
          completed: true,
        ),
        _checkIn(
          at: DateTime.utc(2026, 6, 2),
          goalType: GoalType.task,
          logged: true,
          completed: false,
        ),
      ];

      expect(computeGoalProgress(goal, checkIns), 0.25);
    });
  });

  group('computeGoalStats', () {
    test('never produces missed outcomes in day rollups', () {
      final goal = _goal();
      final checkIns = [
        _checkIn(at: DateTime.utc(2026, 6, 8)),
        _checkIn(
          at: DateTime.utc(2026, 6, 9),
          logged: true,
          countValue: 1,
        ),
      ];

      final stats = computeGoalStats(
        goal,
        checkIns,
        now: DateTime.utc(2026, 6, 10),
      );

      final pendingDay =
          normalizeTaskListCalendarDay(checkIns[0].checkInAt.toLocal());
      final loggedDay =
          normalizeTaskListCalendarDay(checkIns[1].checkInAt.toLocal());

      expect(stats.dayOutcomes[pendingDay], GoalDayOutcome.pending);
      expect(stats.dayOutcomes[loggedDay], GoalDayOutcome.logged);
    });

    test('computes velocity and eta for decreasing count goal', () {
      final weightGoal = Goal(
        id: '1',
        name: 'Weight',
        goalType: GoalType.count,
        target: 75,
        unit: 'kg',
        direction: GoalDirection.decreasing,
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 12, 31),
      );
      final checkIns = [
        _checkIn(
          at: DateTime.utc(2026, 6, 1),
          logged: true,
          countValue: 90,
        ),
        _checkIn(
          at: DateTime.utc(2026, 6, 8),
          logged: true,
          countValue: 81,
        ),
      ];

      final stats = computeGoalStats(
        weightGoal,
        checkIns,
        now: DateTime.utc(2026, 6, 10),
      );

      expect(stats.currentValue, 81);
      expect(stats.velocityPerWeek, closeTo(-9, 0.01));
      expect(stats.loggedCount, 2);
      expect(stats.pace, isNot(GoalPace.unknown));
    });

    test('uses latest snapshot for decreasing count progress', () {
      final goal = Goal(
        id: '1',
        name: 'Weight',
        goalType: GoalType.count,
        target: 75,
        unit: 'kg',
        direction: GoalDirection.decreasing,
        startDate: DateTime.utc(2026, 1, 1),
      );
      final checkIns = [
        _checkIn(
          at: DateTime.utc(2026, 6, 1),
          logged: true,
          countValue: 100,
        ),
        _checkIn(
          at: DateTime.utc(2026, 6, 8),
          logged: true,
          countValue: 81,
        ),
      ];

      expect(computeGoalProgress(goal, checkIns), closeTo(0.76, 0.01));
      expect(
        computeCurrentTargetRingFraction(goal, 81),
        closeTo(75 / 81, 0.01),
      );
    });
  });
}
