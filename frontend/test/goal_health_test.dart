import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/services/goal_health.dart';
import 'package:frontend/features/productivity/services/goal_stats.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';

GoalStats _stats({
  double progressPercent = 50,
  GoalPace pace = GoalPace.onTrack,
}) =>
    GoalStats(
      progressPercent: progressPercent,
      currentStreak: 1,
      bestStreak: 1,
      totalScheduled: 10,
      loggedCount: 5,
      pendingCount: 5,
      consistency: 0.8,
      consistencyLogged: 8,
      consistencyScheduled: 10,
      dayOutcomes: const {},
      weeklyLoggedRates: const [],
      weeklyHasData: const [],
      totalUnitsLogged: 5,
      completedPeriods: 0,
      unitLabel: 'kg',
      pace: pace,
    );

TrackerStats _trackerStats({
  double habitStrength = 80,
  double consistency = 0.9,
}) =>
    TrackerStats(
      strength: habitStrength,
      currentStreak: 3,
      bestStreak: 5,
      totalCheckIns: 10,
      thisWeekPercent: 80,
      succeeded: 8,
      missed: 2,
      skipped: 0,
      successRate: 0.8,
      doneUnits: 0,
      missedUnits: 0,
      doneMinutes: 0,
      missedMinutes: 0,
      dayOutcomes: const {},
      weeklySuccessRates: const [],
      weeklyHasData: const [],
      habitStrength: habitStrength,
      consistency: consistency,
      consistencyCompleted: 9,
      consistencyScheduled: 10,
      unitLabel: null,
    );

void main() {
  group('computeGoalProgressHealthScore', () {
    test('applies pace adjustments', () {
      expect(
        computeGoalProgressHealthScore(_stats(progressPercent: 50)),
        50,
      );
      expect(
        computeGoalProgressHealthScore(
          _stats(progressPercent: 50, pace: GoalPace.ahead),
        ),
        58,
      );
      expect(
        computeGoalProgressHealthScore(
          _stats(progressPercent: 50, pace: GoalPace.behind),
        ),
        38,
      );
    });

    test('clamps to 0-100', () {
      expect(
        computeGoalProgressHealthScore(
          _stats(progressPercent: 5, pace: GoalPace.behind),
        ),
        0,
      );
      expect(
        computeGoalProgressHealthScore(
          _stats(progressPercent: 95, pace: GoalPace.ahead),
        ),
        100,
      );
    });
  });

  group('goalHealthBandForScore', () {
    test('selects band at thresholds', () {
      expect(goalHealthBandForScore(75), GoalHealthBand.strong);
      expect(goalHealthBandForScore(74.9), GoalHealthBand.steady);
      expect(goalHealthBandForScore(50), GoalHealthBand.steady);
      expect(goalHealthBandForScore(49.9), GoalHealthBand.fragile);
      expect(goalHealthBandForScore(25), GoalHealthBand.fragile);
      expect(goalHealthBandForScore(24.9), GoalHealthBand.atRisk);
    });
  });

  group('computeGoalHealth', () {
    test('uses progress score only when no trackers are linked', () {
      final overview = computeGoalHealth(
        stats: _stats(progressPercent: 60),
        trackerStats: const [],
      );

      expect(overview.linkedTrackerCount, 0);
      expect(overview.trackerSupportScore, isNull);
      expect(overview.score, 60);
      expect(overview.progressScore, 60);
      expect(
        overview.summary,
        contains('no supporting trackers linked'),
      );
    });

    test('blends progress and averaged tracker support', () {
      final overview = computeGoalHealth(
        stats: _stats(progressPercent: 60),
        trackerStats: [
          _trackerStats(habitStrength: 80, consistency: 1.0),
          _trackerStats(habitStrength: 60, consistency: 0.8),
        ],
      );

      expect(overview.linkedTrackerCount, 2);
      expect(overview.trackerSupportScore, closeTo(77.0, 0.01));
      expect(overview.score, closeTo(66.8, 0.1));
      expect(overview.averageTrackerStrength, 70);
      expect(overview.averageTrackerConsistency, closeTo(0.9, 0.01));
    });

    test('pace behind lowers overall health through progress score', () {
      final onTrack = computeGoalHealth(
        stats: _stats(progressPercent: 60, pace: GoalPace.onTrack),
        trackerStats: const [],
      );
      final behind = computeGoalHealth(
        stats: _stats(progressPercent: 60, pace: GoalPace.behind),
        trackerStats: const [],
      );

      expect(behind.progressScore, lessThan(onTrack.progressScore));
      expect(behind.score, lessThan(onTrack.score));
    });
  });
}
