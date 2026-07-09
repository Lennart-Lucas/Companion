import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

Tracker _countTracker({num target = 8}) => Tracker(
      id: '1',
      name: 'Water',
      startDate: DateTime.utc(2026, 1, 1),
      checkInType: TrackerCheckInType.count,
      target: target,
      unit: 'glasses',
      habitDirection: TrackerHabitDirection.build,
    );

TrackerCheckIn _checkIn({
  required int id,
  required DateTime at,
  num? countValue,
  bool logged = true,
  bool skipped = false,
}) =>
    TrackerCheckIn(
      id: id,
      checkInAt: at,
      checkInType: TrackerCheckInType.count,
      countValue: countValue,
      logged: logged || skipped || countValue != null,
      skipped: skipped,
    );

void main() {
  final now = DateTime(2026, 6, 15, 12);

  test('classify pending future check-ins', () {
    final tracker = _countTracker();
    final checkIn = _checkIn(
      id: 1,
      at: now.add(const Duration(days: 1)),
      countValue: 8,
    );
    expect(
      classifyTrackerCheckIn(tracker, checkIn, now: now),
      TrackerCheckInOutcome.pending,
    );
  });

  test('classify skipped and missed unlogged', () {
    final tracker = _countTracker();
    expect(
      classifyTrackerCheckIn(
        tracker,
        _checkIn(id: 1, at: now.subtract(const Duration(days: 1)), skipped: true),
        now: now,
      ),
      TrackerCheckInOutcome.skipped,
    );
    expect(
      classifyTrackerCheckIn(
        tracker,
        _checkIn(
          id: 2,
          at: now.subtract(const Duration(days: 2)),
          logged: false,
          countValue: null,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.missed,
    );
  });

  test('task check-in on today stays pending until completed', () {
    final tracker = Tracker(
      id: 'task',
      name: 'Meditation',
      startDate: DateTime.utc(2026, 1, 1),
      checkInType: TrackerCheckInType.task,
      habitDirection: TrackerHabitDirection.build,
    );
    final todayMorning = DateTime(now.year, now.month, now.day, 8);

    expect(
      classifyTrackerCheckIn(
        tracker,
        TrackerCheckIn(
          id: 1,
          checkInAt: todayMorning,
          checkInType: TrackerCheckInType.task,
          logged: false,
          skipped: false,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.pending,
    );
    expect(
      classifyTrackerCheckIn(
        tracker,
        TrackerCheckIn(
          id: 2,
          checkInAt: todayMorning,
          checkInType: TrackerCheckInType.task,
          logged: true,
          skipped: false,
          completed: true,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.succeeded,
    );
    expect(
      classifyTrackerCheckIn(
        tracker,
        TrackerCheckIn(
          id: 3,
          checkInAt: now.subtract(const Duration(days: 1)),
          checkInType: TrackerCheckInType.task,
          logged: false,
          skipped: false,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.missed,
    );
  });

  test('count check-in classification for today, past, and quit over-target', () {
    final buildTracker = _countTracker(target: 8);
    final quitTracker = Tracker(
      id: '2',
      name: 'Sugar',
      startDate: DateTime.utc(2026, 1, 1),
      checkInType: TrackerCheckInType.count,
      target: 3,
      unit: 'snacks',
      habitDirection: TrackerHabitDirection.quit,
    );
    final todayMorning = DateTime(now.year, now.month, now.day, 8);

    expect(
      classifyTrackerCheckIn(
        buildTracker,
        _checkIn(
          id: 1,
          at: todayMorning,
          logged: false,
          countValue: null,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.pending,
    );
    expect(
      classifyTrackerCheckIn(
        buildTracker,
        _checkIn(id: 2, at: todayMorning, countValue: 4),
        now: now,
      ),
      TrackerCheckInOutcome.pending,
    );
    expect(
      classifyTrackerCheckIn(
        buildTracker,
        _checkIn(id: 3, at: todayMorning, countValue: 8),
        now: now,
      ),
      TrackerCheckInOutcome.succeeded,
    );
    expect(
      classifyTrackerCheckIn(
        buildTracker,
        _checkIn(id: 4, at: now.subtract(const Duration(days: 1)), countValue: 5),
        now: now,
      ),
      TrackerCheckInOutcome.missed,
    );
    expect(
      classifyTrackerCheckIn(
        buildTracker,
        _checkIn(id: 5, at: now.subtract(const Duration(days: 1)), countValue: 8),
        now: now,
      ),
      TrackerCheckInOutcome.succeeded,
    );
    expect(
      classifyTrackerCheckIn(
        quitTracker,
        _checkIn(id: 6, at: todayMorning, countValue: 4),
        now: now,
      ),
      TrackerCheckInOutcome.missed,
    );
    expect(
      classifyTrackerCheckIn(
        quitTracker,
        _checkIn(
          id: 7,
          at: now.subtract(const Duration(days: 1)),
          countValue: 2,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.succeeded,
    );
  });

  test('duration check-in on today stays pending until target reached', () {
    final tracker = Tracker(
      id: 'duration',
      name: 'Exercise',
      startDate: DateTime.utc(2026, 1, 1),
      checkInType: TrackerCheckInType.duration,
      target: 1800,
      habitDirection: TrackerHabitDirection.build,
    );
    final todayMorning = DateTime(now.year, now.month, now.day, 8);

    expect(
      classifyTrackerCheckIn(
        tracker,
        TrackerCheckIn(
          id: 1,
          checkInAt: todayMorning,
          checkInType: TrackerCheckInType.duration,
          logged: false,
          skipped: false,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.pending,
    );
    expect(
      classifyTrackerCheckIn(
        tracker,
        TrackerCheckIn(
          id: 2,
          checkInAt: todayMorning,
          checkInType: TrackerCheckInType.duration,
          logged: true,
          skipped: false,
          valueSeconds: 900,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.pending,
    );
    expect(
      classifyTrackerCheckIn(
        tracker,
        TrackerCheckIn(
          id: 3,
          checkInAt: todayMorning,
          checkInType: TrackerCheckInType.duration,
          logged: true,
          skipped: false,
          valueSeconds: 1800,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.succeeded,
    );
    expect(
      classifyTrackerCheckIn(
        tracker,
        TrackerCheckIn(
          id: 4,
          checkInAt: now.subtract(const Duration(days: 1)),
          checkInType: TrackerCheckInType.duration,
          logged: false,
          skipped: false,
        ),
        now: now,
      ),
      TrackerCheckInOutcome.missed,
    );
  });

  test('strength uses last 30 non-skipped check-ins', () {
    final tracker = _countTracker();
    final checkIns = <TrackerCheckIn>[
      for (var i = 0; i < 35; i++)
        _checkIn(
          id: i + 1,
          at: now.subtract(Duration(days: 35 - i)),
          countValue: i >= 10 ? 8 : 2,
        ),
    ];

    final stats = computeTrackerStats(tracker, checkIns, now: now);
    expect(stats.strength, closeTo(25 / 30, 0.001));
  });

  test('strength excludes skipped moments', () {
    final tracker = _countTracker();
    final stats = computeTrackerStats(
      tracker,
      [
        _checkIn(
          id: 1,
          at: now.subtract(const Duration(days: 2)),
          skipped: true,
        ),
        _checkIn(
          id: 2,
          at: now.subtract(const Duration(days: 1)),
          countValue: 8,
        ),
      ],
      now: now,
    );
    expect(stats.strength, 1.0);
    expect(stats.skipped, 1);
  });

  test('current streak breaks on skipped or missed', () {
    final tracker = _countTracker();
    final stats = computeTrackerStats(
      tracker,
      [
        _checkIn(id: 1, at: now.subtract(const Duration(days: 4)), countValue: 8),
        _checkIn(id: 2, at: now.subtract(const Duration(days: 3)), countValue: 8),
        _checkIn(id: 3, at: now.subtract(const Duration(days: 2)), countValue: 2),
        _checkIn(id: 4, at: now.subtract(const Duration(days: 1)), countValue: 8),
      ],
      now: now,
    );
    expect(stats.currentStreak, 1);
    expect(stats.bestStreak, 2);
  });

  test('success rate excludes skipped from denominator', () {
    final tracker = _countTracker();
    final stats = computeTrackerStats(
      tracker,
      [
        _checkIn(id: 1, at: now.subtract(const Duration(days: 3)), countValue: 8),
        _checkIn(id: 2, at: now.subtract(const Duration(days: 2)), countValue: 2),
        _checkIn(
          id: 3,
          at: now.subtract(const Duration(days: 1)),
          skipped: true,
        ),
      ],
      now: now,
    );
    expect(stats.succeeded, 1);
    expect(stats.missed, 1);
    expect(stats.skipped, 1);
    expect(stats.successRate, 0.5);
  });

  test('count totals sum done and missed units', () {
    final tracker = _countTracker(target: 10);
    final stats = computeTrackerStats(
      tracker,
      [
        _checkIn(id: 1, at: now.subtract(const Duration(days: 2)), countValue: 10),
        _checkIn(id: 2, at: now.subtract(const Duration(days: 1)), countValue: 4),
      ],
      now: now,
    );
    expect(stats.doneUnits, 10);
    expect(stats.missedUnits, 6);
    expect(stats.unitLabel, 'glasses');
  });

  test('day outcomes prefer success over missed on same day', () {
    final tracker = _countTracker();
    final day = normalizeTaskListCalendarDay(now.subtract(const Duration(days: 1)));
    final stats = computeTrackerStats(
      tracker,
      [
        _checkIn(
          id: 1,
          at: day.add(const Duration(hours: 8)),
          countValue: 2,
        ),
        _checkIn(
          id: 2,
          at: day.add(const Duration(hours: 20)),
          countValue: 8,
        ),
      ],
      now: now,
    );
    expect(stats.dayOutcomes[day], TrackerDayOutcome.succeeded);
  });

  test('quit habit succeeds when count is at or below target', () {
    final tracker = Tracker(
      id: '2',
      name: 'Sugar',
      startDate: DateTime.utc(2026, 1, 1),
      checkInType: TrackerCheckInType.count,
      target: 3,
      unit: 'snacks',
      habitDirection: TrackerHabitDirection.quit,
    );
    expect(
      isTrackerTargetReached(
        tracker,
        _checkIn(
          id: 1,
          at: now.subtract(const Duration(days: 1)),
          countValue: 2,
        ),
      ),
      isTrue,
    );
    expect(
      isTrackerTargetReached(
        tracker,
        _checkIn(
          id: 2,
          at: now.subtract(const Duration(days: 1)),
          countValue: 5,
        ),
      ),
      isFalse,
    );
  });

  test('habit strength grows on consecutive completed days', () {
    final start = DateTime(2026, 6, 1);
    final strength = computeHabitStrength(
      trackerStart: start,
      reference: DateTime(2026, 6, 3),
      dayOutcomes: {
        DateTime(2026, 6, 1): TrackerDayOutcome.succeeded,
        DateTime(2026, 6, 2): TrackerDayOutcome.succeeded,
        DateTime(2026, 6, 3): TrackerDayOutcome.succeeded,
      },
    );
    expect(strength, closeTo(22.11, 0.1));
  });

  test('habit strength decays slowly then faster on consecutive misses', () {
    var strength = 98.0;
    var consecutiveMisses = 0;
    for (var i = 0; i < 3; i++) {
      consecutiveMisses += 1;
      final decay = 0.005 + consecutiveMisses * 0.003;
      strength -= strength * decay;
    }
    expect(strength, closeTo(94.8, 0.2));

    final fromHigh = computeHabitStrength(
      trackerStart: DateTime(2026, 1, 1),
      reference: DateTime(2026, 1, 10),
      dayOutcomes: {
        for (var i = 1; i <= 9; i++)
          DateTime(2026, 1, i): TrackerDayOutcome.succeeded,
        DateTime(2026, 1, 10): TrackerDayOutcome.missed,
      },
    );
    // 9 days of growth then 1 miss — should be high but below asymptote.
    expect(fromHigh, greaterThan(50));
  });

  test('habit strength skips today while pending', () {
    final start = DateTime(2026, 6, 1);
    final withPending = computeHabitStrength(
      trackerStart: start,
      reference: DateTime(2026, 6, 2),
      dayOutcomes: {
        DateTime(2026, 6, 1): TrackerDayOutcome.succeeded,
        DateTime(2026, 6, 2): TrackerDayOutcome.pending,
      },
    );
    final withoutPending = computeHabitStrength(
      trackerStart: start,
      reference: DateTime(2026, 6, 1),
      dayOutcomes: {
        DateTime(2026, 6, 1): TrackerDayOutcome.succeeded,
      },
    );
    expect(withPending, closeTo(withoutPending, 0.001));
  });

  test('consistency uses last 30 scheduled days', () {
    final start = DateTime(2026, 1, 1);
    final reference = DateTime(2026, 1, 30);
    final outcomes = <DateTime, TrackerDayOutcome>{};
    for (var i = 0; i < 30; i++) {
      final day = start.add(Duration(days: i));
      outcomes[day] =
          i < 29 ? TrackerDayOutcome.succeeded : TrackerDayOutcome.missed;
    }

    final result = computeTrackerConsistency(
      trackerStart: start,
      trackerEnd: null,
      reference: reference,
      dayOutcomes: outcomes,
    );

    expect(result.scheduled, 30);
    expect(result.completed, 29);
    expect(result.rate, closeTo(29 / 30, 0.001));
  });

  test('consistency window caps at 30 when tracker is older', () {
    final start = DateTime(2026, 1, 1);
    final reference = DateTime(2026, 3, 1);
    final outcomes = <DateTime, TrackerDayOutcome>{};
    for (var i = 0; i < 60; i++) {
      outcomes[start.add(Duration(days: i))] = TrackerDayOutcome.succeeded;
    }
    // Miss the last day in the 30-day window.
    outcomes[DateTime(2026, 3, 1)] = TrackerDayOutcome.missed;

    final result = computeTrackerConsistency(
      trackerStart: start,
      trackerEnd: null,
      reference: reference,
      dayOutcomes: outcomes,
    );

    expect(result.scheduled, 30);
    expect(result.completed, 29);
  });

  test('consistency counts missed and skipped as not completed', () {
    final start = DateTime(2026, 6, 1);
    final result = computeTrackerConsistency(
      trackerStart: start,
      trackerEnd: null,
      reference: DateTime(2026, 6, 3),
      dayOutcomes: {
        DateTime(2026, 6, 1): TrackerDayOutcome.succeeded,
        DateTime(2026, 6, 2): TrackerDayOutcome.missed,
        DateTime(2026, 6, 3): TrackerDayOutcome.skipped,
      },
    );
    expect(result.scheduled, 3);
    expect(result.completed, 1);
    expect(result.rate, closeTo(1 / 3, 0.001));
  });
}
