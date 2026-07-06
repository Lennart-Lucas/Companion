import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/check_in_display.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

/// Outcome of a single check-in moment for stats.
enum TrackerCheckInOutcome {
  pending,
  succeeded,
  missed,
  skipped,
}

/// Rolled-up outcome for a local calendar day (may have multiple moments).
enum TrackerDayOutcome {
  pending,
  succeeded,
  missed,
  skipped,
}

/// Aggregated tracker statistics computed client-side from check-ins.
class TrackerStats {
  const TrackerStats({
    required this.strength,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCheckIns,
    required this.thisWeekPercent,
    required this.succeeded,
    required this.missed,
    required this.skipped,
    required this.successRate,
    required this.doneUnits,
    required this.missedUnits,
    required this.doneMinutes,
    required this.missedMinutes,
    required this.dayOutcomes,
    required this.weeklySuccessRates,
    required this.unitLabel,
  });

  final double strength;
  final int currentStreak;
  final int bestStreak;
  final int totalCheckIns;
  final double thisWeekPercent;
  final int succeeded;
  final int missed;
  final int skipped;
  final double successRate;
  final num doneUnits;
  final num missedUnits;
  final num doneMinutes;
  final num missedMinutes;
  final Map<DateTime, TrackerDayOutcome> dayOutcomes;
  final List<double> weeklySuccessRates;
  final String? unitLabel;

  static const empty = TrackerStats(
    strength: 0,
    currentStreak: 0,
    bestStreak: 0,
    totalCheckIns: 0,
    thisWeekPercent: 0,
    succeeded: 0,
    missed: 0,
    skipped: 0,
    successRate: 0,
    doneUnits: 0,
    missedUnits: 0,
    doneMinutes: 0,
    missedMinutes: 0,
    dayOutcomes: {},
    weeklySuccessRates: [],
    unitLabel: null,
  );
}

class _EvaluatedCheckIn {
  const _EvaluatedCheckIn({
    required this.checkIn,
    required this.outcome,
  });

  final TrackerCheckIn checkIn;
  final TrackerCheckInOutcome outcome;
}

TrackerCheckInOutcome classifyTrackerCheckIn(
  Tracker tracker,
  TrackerCheckIn checkIn, {
  required DateTime now,
}) {
  if (checkIn.slotKind == CheckInSlotKind.periodMiss) {
    return TrackerCheckInOutcome.missed;
  }
  final displayAt = checkIn.displayAtFor(tracker, now: now);
  if (displayAt.isAfter(now)) {
    return TrackerCheckInOutcome.pending;
  }
  if (checkIn.skipped) {
    return TrackerCheckInOutcome.skipped;
  }

  final checkInDay = normalizeTaskListCalendarDay(displayAt.toLocal());
  final today = normalizeTaskListCalendarDay(now.toLocal());
  if (tracker.checkInType == TrackerCheckInType.task && checkInDay == today) {
    if (checkIn.logged && isTrackerTargetReached(tracker, checkIn)) {
      return TrackerCheckInOutcome.succeeded;
    }
    return TrackerCheckInOutcome.pending;
  }

  if (tracker.checkInType == TrackerCheckInType.count) {
    if (tracker.habitDirection == TrackerHabitDirection.quit &&
        checkIn.countValue != null &&
        tracker.target != null &&
        checkIn.countValue! > tracker.target!) {
      return TrackerCheckInOutcome.missed;
    }
    if (checkInDay == today) {
      if (checkIn.logged && isTrackerTargetReached(tracker, checkIn)) {
        return TrackerCheckInOutcome.succeeded;
      }
      return TrackerCheckInOutcome.pending;
    }
  }

  if (tracker.checkInType == TrackerCheckInType.duration) {
    if (tracker.habitDirection == TrackerHabitDirection.quit &&
        checkIn.valueSeconds != null &&
        tracker.target != null &&
        checkIn.valueSeconds! > tracker.target!.toInt()) {
      return TrackerCheckInOutcome.missed;
    }
    if (checkInDay == today) {
      if (checkIn.logged && isTrackerTargetReached(tracker, checkIn)) {
        return TrackerCheckInOutcome.succeeded;
      }
      return TrackerCheckInOutcome.pending;
    }
  }

  if (!checkIn.logged) {
    return TrackerCheckInOutcome.missed;
  }
  if (isTrackerTargetReached(tracker, checkIn)) {
    return TrackerCheckInOutcome.succeeded;
  }
  return TrackerCheckInOutcome.missed;
}

TrackerStats computeTrackerStats(
  Tracker tracker,
  List<TrackerCheckIn> checkIns, {
  DateTime? now,
}) {
  if (checkIns.isEmpty) {
    return TrackerStats.empty.copyWith(
      unitLabel: tracker.checkInType == TrackerCheckInType.count
          ? tracker.unit?.trim()
          : null,
    );
  }

  final reference = now ?? DateTime.now();
  final sorted = [...checkIns]
    ..sort((a, b) => a.checkInAt.compareTo(b.checkInAt));

  final evaluated = sorted
      .map(
        (checkIn) => _EvaluatedCheckIn(
          checkIn: checkIn,
          outcome: classifyTrackerCheckIn(tracker, checkIn, now: reference),
        ),
      )
      .toList();

  final past = evaluated
      .where((e) => e.outcome != TrackerCheckInOutcome.pending)
      .toList();

  final strengthPool =
      past.where((e) => e.outcome != TrackerCheckInOutcome.skipped).toList();
  final strengthWindow = strengthPool.length > 30
      ? strengthPool.sublist(strengthPool.length - 30)
      : strengthPool;
  final strength = strengthWindow.isEmpty
      ? 0.0
      : strengthWindow
              .where((e) => e.outcome == TrackerCheckInOutcome.succeeded)
              .length /
          strengthWindow.length;

  final succeeded =
      past.where((e) => e.outcome == TrackerCheckInOutcome.succeeded).length;
  final missed =
      past.where((e) => e.outcome == TrackerCheckInOutcome.missed).length;
  final skipped =
      past.where((e) => e.outcome == TrackerCheckInOutcome.skipped).length;

  final successDenominator = succeeded + missed;
  final successRate =
      successDenominator == 0 ? 0.0 : succeeded / successDenominator;

  final weekStart = taskListWeekStart(reference);
  final weekEnd = weekStart.add(const Duration(days: 7));
  final thisWeekEvaluated = past.where((e) {
    final local = normalizeTaskListCalendarDay(e.checkIn.checkInAt.toLocal());
    return !local.isBefore(weekStart) && local.isBefore(weekEnd);
  });
  final weekSucceeded = thisWeekEvaluated
      .where((e) => e.outcome == TrackerCheckInOutcome.succeeded)
      .length;
  final weekMissed = thisWeekEvaluated
      .where((e) => e.outcome == TrackerCheckInOutcome.missed)
      .length;
  final weekDenominator = weekSucceeded + weekMissed;
  final thisWeekPercent =
      weekDenominator == 0 ? 0.0 : weekSucceeded / weekDenominator;

  final dayOutcomes = _rollupDayOutcomes(evaluated);
  final weeklySuccessRates = _weeklySuccessRates(past, reference);

  final countTotals = tracker.checkInType == TrackerCheckInType.count
      ? _countTotals(tracker, past)
      : (done: 0.0, missed: 0.0);
  final durationTotals = tracker.checkInType == TrackerCheckInType.duration
      ? _durationTotals(tracker, past)
      : (done: 0.0, missed: 0.0);

  return TrackerStats(
    strength: strength,
    currentStreak: _currentStreak(past),
    bestStreak: _bestStreak(past),
    totalCheckIns: past.length,
    thisWeekPercent: thisWeekPercent,
    succeeded: succeeded,
    missed: missed,
    skipped: skipped,
    successRate: successRate,
    doneUnits: countTotals.done,
    missedUnits: countTotals.missed,
    doneMinutes: durationTotals.done,
    missedMinutes: durationTotals.missed,
    dayOutcomes: dayOutcomes,
    weeklySuccessRates: weeklySuccessRates,
    unitLabel: tracker.checkInType == TrackerCheckInType.count
        ? tracker.unit?.trim()
        : null,
  );
}

extension on TrackerStats {
  TrackerStats copyWith({
    String? unitLabel,
  }) {
    return TrackerStats(
      strength: strength,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalCheckIns: totalCheckIns,
      thisWeekPercent: thisWeekPercent,
      succeeded: succeeded,
      missed: missed,
      skipped: skipped,
      successRate: successRate,
      doneUnits: doneUnits,
      missedUnits: missedUnits,
      doneMinutes: doneMinutes,
      missedMinutes: missedMinutes,
      dayOutcomes: dayOutcomes,
      weeklySuccessRates: weeklySuccessRates,
      unitLabel: unitLabel ?? this.unitLabel,
    );
  }
}

Map<DateTime, TrackerDayOutcome> _rollupDayOutcomes(
  List<_EvaluatedCheckIn> evaluated,
) {
  final byDay = <DateTime, List<TrackerCheckInOutcome>>{};
  for (final item in evaluated) {
    final key = normalizeTaskListCalendarDay(item.checkIn.checkInAt.toLocal());
    byDay.putIfAbsent(key, () => []).add(item.outcome);
  }

  final result = <DateTime, TrackerDayOutcome>{};
  for (final entry in byDay.entries) {
    final outcomes = entry.value;
    if (outcomes.every((o) => o == TrackerCheckInOutcome.pending)) {
      result[entry.key] = TrackerDayOutcome.pending;
    } else if (outcomes.contains(TrackerCheckInOutcome.succeeded)) {
      result[entry.key] = TrackerDayOutcome.succeeded;
    } else if (outcomes.contains(TrackerCheckInOutcome.missed)) {
      result[entry.key] = TrackerDayOutcome.missed;
    } else {
      result[entry.key] = TrackerDayOutcome.skipped;
    }
  }
  return result;
}

int _currentStreak(List<_EvaluatedCheckIn> past) {
  if (past.isEmpty) return 0;

  var streak = 0;
  for (var i = past.length - 1; i >= 0; i--) {
    final outcome = past[i].outcome;
    if (outcome == TrackerCheckInOutcome.skipped) break;
    if (outcome == TrackerCheckInOutcome.succeeded) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

int _bestStreak(List<_EvaluatedCheckIn> past) {
  var best = 0;
  var current = 0;
  for (final item in past) {
    switch (item.outcome) {
      case TrackerCheckInOutcome.succeeded:
        current++;
        if (current > best) best = current;
      case TrackerCheckInOutcome.skipped:
        current = 0;
      case TrackerCheckInOutcome.missed:
        current = 0;
      case TrackerCheckInOutcome.pending:
        break;
    }
  }
  return best;
}

List<double> _weeklySuccessRates(
  List<_EvaluatedCheckIn> past,
  DateTime reference,
) {
  final currentWeekStart = taskListWeekStart(reference);
  final rates = <double>[];

  for (var offset = 7; offset >= 0; offset--) {
    final weekStart = currentWeekStart.subtract(Duration(days: 7 * offset));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekItems = past.where((e) {
      final local = normalizeTaskListCalendarDay(e.checkIn.checkInAt.toLocal());
      return !local.isBefore(weekStart) && local.isBefore(weekEnd);
    });
    final succeeded = weekItems
        .where((e) => e.outcome == TrackerCheckInOutcome.succeeded)
        .length;
    final missed = weekItems
        .where((e) => e.outcome == TrackerCheckInOutcome.missed)
        .length;
    final denominator = succeeded + missed;
    rates.add(denominator == 0 ? 0.0 : succeeded / denominator);
  }
  return rates;
}

({num done, num missed}) _countTotals(
  Tracker tracker,
  List<_EvaluatedCheckIn> past,
) {
  final target = tracker.target;
  if (target == null) return (done: 0, missed: 0);

  final build = tracker.habitDirection == TrackerHabitDirection.build;
  num done = 0;
  num missed = 0;

  for (final item in past) {
    switch (item.outcome) {
      case TrackerCheckInOutcome.succeeded:
        done += item.checkIn.countValue ?? 0;
      case TrackerCheckInOutcome.missed:
        final value = item.checkIn.countValue;
        if (value == null) {
          missed += target;
        } else if (build) {
          missed += (target - value).clamp(0, target);
        } else {
          missed += (value - target).clamp(0, value);
        }
      case TrackerCheckInOutcome.skipped:
      case TrackerCheckInOutcome.pending:
        break;
    }
  }
  return (done: done, missed: missed);
}

({num done, num missed}) _durationTotals(
  Tracker tracker,
  List<_EvaluatedCheckIn> past,
) {
  final target = tracker.target?.toInt();
  if (target == null) return (done: 0, missed: 0);

  final build = tracker.habitDirection == TrackerHabitDirection.build;
  num done = 0;
  num missed = 0;

  for (final item in past) {
    switch (item.outcome) {
      case TrackerCheckInOutcome.succeeded:
        done += (item.checkIn.valueSeconds ?? 0) / 60;
      case TrackerCheckInOutcome.missed:
        final value = item.checkIn.valueSeconds;
        if (value == null) {
          missed += target / 60;
        } else if (build) {
          missed += ((target - value).clamp(0, target)) / 60;
        } else {
          missed += ((value - target).clamp(0, value)) / 60;
        }
      case TrackerCheckInOutcome.skipped:
      case TrackerCheckInOutcome.pending:
        break;
    }
  }
  return (done: done, missed: missed);
}

TrackerDayOutcome? trackerDayOutcomeOn(
  Map<DateTime, TrackerDayOutcome> dayOutcomes,
  DateTime day,
) {
  return dayOutcomes[normalizeTaskListCalendarDay(day)];
}
