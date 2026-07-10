import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
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
    required this.weeklyHasData,
    required this.habitStrength,
    required this.consistency,
    required this.consistencyCompleted,
    required this.consistencyScheduled,
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
  final List<bool> weeklyHasData;
  /// Ingrained habit health (0–100), built slowly day by day.
  final double habitStrength;
  /// Recent completion rate over the last 30 scheduled days (0–1).
  final double consistency;
  final int consistencyCompleted;
  final int consistencyScheduled;
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
    weeklyHasData: [],
    habitStrength: 0,
    consistency: 0,
    consistencyCompleted: 0,
    consistencyScheduled: 0,
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

/// Whether a quit tracker has exceeded its daily limit (count, duration, or task).
bool quitTrackerLimitExceeded(
  Tracker tracker,
  TrackerCheckIn checkIn, {
  DateTime? now,
}) {
  if (tracker.habitDirection != TrackerHabitDirection.quit) return false;

  switch (tracker.checkInType) {
    case TrackerCheckInType.count:
      final target = tracker.target;
      final value = checkIn.countValue;
      return target != null && value != null && value > target;
    case TrackerCheckInType.duration:
      final target = tracker.target?.toInt();
      if (target == null) return false;
      final elapsed = trackerCheckInElapsedSeconds(
        checkIn,
        now ?? DateTime.now(),
      );
      return elapsed > target;
    case TrackerCheckInType.task:
      return checkIn.completed == true;
    default:
      return false;
  }
}

TrackerCheckInOutcome _classifyQuitTrackerCheckIn(
  Tracker tracker,
  TrackerCheckIn checkIn, {
  required DateTime checkInDay,
  required DateTime today,
  required DateTime now,
}) {
  if (quitTrackerLimitExceeded(tracker, checkIn, now: now)) {
    return TrackerCheckInOutcome.missed;
  }
  if (checkInDay == today) {
    return TrackerCheckInOutcome.pending;
  }
  if (!checkIn.logged) {
    return TrackerCheckInOutcome.missed;
  }
  if (isTrackerTargetReached(tracker, checkIn)) {
    return TrackerCheckInOutcome.succeeded;
  }
  return TrackerCheckInOutcome.missed;
}

TrackerCheckInOutcome classifyTrackerCheckIn(
  Tracker tracker,
  TrackerCheckIn checkIn, {
  required DateTime now,
}) {
  final checkInDay = normalizeTaskListCalendarDay(checkIn.checkInAt.toLocal());
  final today = normalizeTaskListCalendarDay(now.toLocal());

  if (checkInDay.isAfter(today)) {
    return TrackerCheckInOutcome.pending;
  }
  if (checkIn.skipped) {
    return TrackerCheckInOutcome.skipped;
  }

  if (tracker.habitDirection == TrackerHabitDirection.quit) {
    return _classifyQuitTrackerCheckIn(
      tracker,
      checkIn,
      checkInDay: checkInDay,
      today: today,
      now: now,
    );
  }

  if (tracker.checkInType == TrackerCheckInType.task && checkInDay == today) {
    if (checkIn.logged && isTrackerTargetReached(tracker, checkIn)) {
      return TrackerCheckInOutcome.succeeded;
    }
    return TrackerCheckInOutcome.pending;
  }

  if (tracker.checkInType == TrackerCheckInType.count ||
      tracker.checkInType == TrackerCheckInType.duration) {
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
    final reference = now ?? DateTime.now();
    final consistency = computeTrackerConsistency(
      dayOutcomes: const {},
      trackerStart: tracker.startDate,
      trackerEnd: tracker.endDate,
      reference: reference,
    );
    return TrackerStats.empty.copyWith(
      habitStrength: computeHabitStrength(
        dayOutcomes: const {},
        trackerStart: tracker.startDate,
        reference: reference,
      ),
      consistency: consistency.rate,
      consistencyCompleted: consistency.completed,
      consistencyScheduled: consistency.scheduled,
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

  final dayOutcomes = _rollupDayOutcomes(tracker, evaluated);
  final weeklyTrend = _weeklyTrend(past, reference);
  final habitStrength = computeHabitStrength(
    dayOutcomes: dayOutcomes,
    trackerStart: tracker.startDate,
    reference: reference,
  );
  final consistency = computeTrackerConsistency(
    dayOutcomes: dayOutcomes,
    trackerStart: tracker.startDate,
    trackerEnd: tracker.endDate,
    reference: reference,
  );

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
    weeklySuccessRates: weeklyTrend.rates,
    weeklyHasData: weeklyTrend.hasData,
    habitStrength: habitStrength,
    consistency: consistency.rate,
    consistencyCompleted: consistency.completed,
    consistencyScheduled: consistency.scheduled,
    unitLabel: tracker.checkInType == TrackerCheckInType.count
        ? tracker.unit?.trim()
        : null,
  );
}

extension on TrackerStats {
  TrackerStats copyWith({
    String? unitLabel,
    double? habitStrength,
    double? consistency,
    int? consistencyCompleted,
    int? consistencyScheduled,
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
      weeklyHasData: weeklyHasData,
      habitStrength: habitStrength ?? this.habitStrength,
      consistency: consistency ?? this.consistency,
      consistencyCompleted: consistencyCompleted ?? this.consistencyCompleted,
      consistencyScheduled: consistencyScheduled ?? this.consistencyScheduled,
      unitLabel: unitLabel ?? this.unitLabel,
    );
  }
}

/// Habit strength health (0–100) from daily outcomes between [trackerStart] and [reference].
///
/// Completed days grow strength toward 100; misses apply compounding decay that
/// worsens with consecutive misses. Today while still pending is skipped.
double computeHabitStrength({
  required Map<DateTime, TrackerDayOutcome> dayOutcomes,
  required DateTime trackerStart,
  required DateTime reference,
}) {
  var strength = 0.0;
  var consecutiveMisses = 0;
  final start = normalizeTaskListCalendarDay(trackerStart);
  final end = normalizeTaskListCalendarDay(reference);
  if (end.isBefore(start)) return 0;

  for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
    final outcome = dayOutcomes[day];
    final isToday = day == end;

    if (outcome == TrackerDayOutcome.succeeded) {
      strength += (100 - strength) * 0.08;
      consecutiveMisses = 0;
    } else if (outcome == TrackerDayOutcome.pending && isToday) {
      continue;
    } else {
      consecutiveMisses += 1;
      final decay = 0.005 + consecutiveMisses * 0.003;
      strength -= strength * decay;
    }
    strength = strength.clamp(0.0, 100.0);
  }
  return strength;
}

/// Recent consistency over the last 30 scheduled calendar days (0–1 rate).
({double rate, int completed, int scheduled}) computeTrackerConsistency({
  required Map<DateTime, TrackerDayOutcome> dayOutcomes,
  required DateTime trackerStart,
  required DateTime? trackerEnd,
  required DateTime reference,
  int windowSize = 30,
}) {
  final start = normalizeTaskListCalendarDay(trackerStart);
  final today = normalizeTaskListCalendarDay(reference);
  final rangeEnd = trackerEnd != null
      ? normalizeTaskListCalendarDay(trackerEnd)
      : today;
  final effectiveEnd = rangeEnd.isBefore(today) ? rangeEnd : today;
  if (effectiveEnd.isBefore(start)) {
    return (rate: 0.0, completed: 0, scheduled: 0);
  }

  final scheduledDays = <DateTime>[];
  for (var day = start;
      !day.isAfter(effectiveEnd);
      day = day.add(const Duration(days: 1))) {
    final outcome = dayOutcomes[day];
    if (day == today && outcome == TrackerDayOutcome.pending) continue;
    scheduledDays.add(day);
  }

  final window = scheduledDays.length > windowSize
      ? scheduledDays.sublist(scheduledDays.length - windowSize)
      : scheduledDays;
  if (window.isEmpty) {
    return (rate: 0.0, completed: 0, scheduled: 0);
  }

  var completed = 0;
  for (final day in window) {
    if (dayOutcomes[day] == TrackerDayOutcome.succeeded) {
      completed++;
    }
  }

  return (
    rate: completed / window.length,
    completed: completed,
    scheduled: window.length,
  );
}

Map<DateTime, TrackerDayOutcome> _rollupDayOutcomes(
  Tracker tracker,
  List<_EvaluatedCheckIn> evaluated,
) {
  final quit = tracker.habitDirection == TrackerHabitDirection.quit;
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
    } else if (quit && outcomes.contains(TrackerCheckInOutcome.missed)) {
      result[entry.key] = TrackerDayOutcome.missed;
    } else if (!quit && outcomes.contains(TrackerCheckInOutcome.succeeded)) {
      result[entry.key] = TrackerDayOutcome.succeeded;
    } else if (outcomes.contains(TrackerCheckInOutcome.missed)) {
      result[entry.key] = TrackerDayOutcome.missed;
    } else if (outcomes.contains(TrackerCheckInOutcome.succeeded)) {
      result[entry.key] = TrackerDayOutcome.succeeded;
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

({List<double> rates, List<bool> hasData}) _weeklyTrend(
  List<_EvaluatedCheckIn> past,
  DateTime reference,
) {
  final currentWeekStart = taskListWeekStart(reference);
  final rates = <double>[];
  final hasData = <bool>[];

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
    hasData.add(denominator > 0);
  }
  return (rates: rates, hasData: hasData);
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
