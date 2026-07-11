import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/goals/models/goal_milestone.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/goals/services/goal_stats.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_stat_items.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';

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
      expect(computeGoalStartValue(goal, checkIns), 100);
      expect(
        computeCurrentTargetRingFraction(
          goal,
          startValue: 100,
          currentValue: 81,
        ),
        closeTo(0.76, 0.01),
      );
    });

    test('current-target ring spans start value to target for increasing count', () {
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

      expect(computeGoalStartValue(goal, checkIns), 0);
      expect(
        computeCurrentTargetRingFraction(
          goal,
          startValue: 0,
          currentValue: 7,
        ),
        closeTo(0.7, 0.01),
      );
    });

    test('eta ring reflects elapsed share of elapsed plus remaining', () {
      final goal = Goal(
        id: '1',
        name: 'Weight',
        goalType: GoalType.count,
        target: 75,
        unit: 'kg',
        direction: GoalDirection.decreasing,
        startDate: DateTime.utc(2026, 4, 1),
      );
      final now = DateTime.utc(2026, 4, 22); // 3 weeks after start

      expect(
        computeGoalEtaRingFraction(goal, 9, now: now),
        closeTo(3 / 12, 0.05),
      );
      expect(computeGoalEtaRingFraction(goal, 0, now: now), 1);
      expect(computeGoalEtaRingFraction(goal, null, now: now), 0);
    });
  });

  group('goalCheckInValueTimeline', () {
    test('tracks latest snapshot for decreasing count goals', () {
      final goal = _goal(
        target: 75,
        direction: GoalDirection.decreasing,
      );
      final checkIns = [
        _checkIn(
          at: DateTime.utc(2026, 4, 1),
          logged: true,
          countValue: 88,
        ),
        _checkIn(
          at: DateTime.utc(2026, 5, 1),
          logged: true,
          countValue: 81,
        ),
      ];

      final timeline = goalCheckInValueTimeline(goal, checkIns);
      expect(timeline.length, 2);
      expect(timeline.first.value, 88);
      expect(timeline.last.value, 81);
    });
  });

  group('buildGoalProgressBarMarkers', () {
    test('includes start, milestones, now, and goal for decreasing goals', () {
      final goal = Goal(
        id: '1',
        name: 'Weight',
        goalType: GoalType.count,
        target: 75,
        unit: 'kg',
        direction: GoalDirection.decreasing,
        startDate: DateTime.utc(2026, 4, 1),
        milestones: const [
          GoalMilestone(value: 85),
          GoalMilestone(value: 78, sortOrder: 1),
        ],
      );
      final stats = GoalStats(
        progressPercent: 50,
        currentStreak: 1,
        bestStreak: 1,
        totalScheduled: 1,
        loggedCount: 2,
        pendingCount: 0,
        consistency: 100,
        consistencyLogged: 1,
        consistencyScheduled: 1,
        dayOutcomes: const {},
        weeklyLoggedRates: const [],
        weeklyHasData: const [],
        totalUnitsLogged: 0,
        completedPeriods: 0,
        unitLabel: 'kg',
        currentValue: 81,
        startValue: 88,
      );

      final markers = buildGoalProgressBarMarkers(goal, stats);
      expect(markers.first.suffix, isNull);
      expect(markers.last.suffix, isNull);
      expect(
        markers.map((marker) => marker.suffix).toList(),
        containsAll(['now', null]),
      );
      expect(
        goalValueProgressFraction(
          goal,
          startValue: 88,
          value: 81,
        ),
        closeTo(7 / 13, 0.01),
      );
    });
  });

  group('filterGoalValueTimeline', () {
    test('keeps only points within selected range', () {
      final timeline = [
        (at: DateTime.utc(2026, 5, 1), value: 90),
        (at: DateTime.utc(2026, 6, 1), value: 85),
        (at: DateTime.utc(2026, 6, 20), value: 82),
      ];
      final filtered = filterGoalValueTimeline(
        timeline,
        GoalValueChartRange.days30,
        DateTime.utc(2026, 6, 20),
      );

      expect(filtered.length, 2);
      expect(filtered.first.value, 85);
    });
  });

  group('buildGoalSidebarStatItems', () {
    test('includes ETA between velocity and pace', () {
      final goal = _goal(
        target: 75,
        direction: GoalDirection.decreasing,
      );
      final stats = computeGoalStats(
        goal,
        [
          _checkIn(
            at: DateTime.utc(2026, 4, 1),
            logged: true,
            countValue: 88,
          ),
          _checkIn(
            at: DateTime.utc(2026, 5, 1),
            logged: true,
            countValue: 81,
          ),
        ],
        now: DateTime.utc(2026, 5, 15),
      );

      final items = buildGoalSidebarStatItems(goal: goal, stats: stats);
      final labels = items.map((item) => item.label).toList();

      expect(labels, contains('ETA'));
      expect(labels.indexOf('ETA'), labels.indexOf('Velocity') + 1);
      expect(
        items.firstWhere((item) => item.label == 'ETA').value,
        isNot('—'),
      );
    });
  });
}
