import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/goals/models/goal_milestone.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/shared/services/quota_check_in_display.dart';


/// Outcome of a single goal check-in moment.
enum GoalCheckInOutcome {
  pending,
  logged,
  missed,
}

/// Rolled-up outcome for a local calendar day (may have multiple moments).
enum GoalDayOutcome {
  pending,
  logged,
  missed,
}

/// Whether progress is ahead of, on, or behind the schedule.
enum GoalPace {
  ahead,
  onTrack,
  behind,
  unknown,
}

/// Aggregated goal statistics computed client-side from check-ins.
class GoalStats {
  const GoalStats({
    required this.progressPercent,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalScheduled,
    required this.loggedCount,
    required this.pendingCount,
    required this.consistency,
    required this.consistencyLogged,
    required this.consistencyScheduled,
    required this.dayOutcomes,
    required this.weeklyLoggedRates,
    required this.weeklyHasData,
    required this.totalUnitsLogged,
    required this.completedPeriods,
    required this.unitLabel,
    this.currentValue,
    this.startValue,
    this.velocityPerWeek,
    this.pace = GoalPace.unknown,
    this.etaWeeks,
  });

  final double progressPercent;
  final int currentStreak;
  final int bestStreak;
  final int totalScheduled;
  final int loggedCount;
  final int pendingCount;
  final double consistency;
  final int consistencyLogged;
  final int consistencyScheduled;
  final Map<DateTime, GoalDayOutcome> dayOutcomes;
  final List<double> weeklyLoggedRates;
  final List<bool> weeklyHasData;
  final num totalUnitsLogged;
  final int completedPeriods;
  final String? unitLabel;
  final num? currentValue;
  final num? startValue;
  final num? velocityPerWeek;
  final GoalPace pace;
  final int? etaWeeks;

  static const empty = GoalStats(
    progressPercent: 0,
    currentStreak: 0,
    bestStreak: 0,
    totalScheduled: 0,
    loggedCount: 0,
    pendingCount: 0,
    consistency: 0,
    consistencyLogged: 0,
    consistencyScheduled: 0,
    dayOutcomes: {},
    weeklyLoggedRates: [],
    weeklyHasData: [],
    totalUnitsLogged: 0,
    completedPeriods: 0,
    unitLabel: null,
  );
}

class _EvaluatedGoalCheckIn {
  const _EvaluatedGoalCheckIn({
    required this.checkIn,
    required this.outcome,
  });

  final GoalCheckIn checkIn;
  final GoalCheckInOutcome outcome;
}

/// Classifies a goal check-in as logged, pending, or missed (quota failures).
GoalCheckInOutcome classifyGoalCheckIn(
  GoalCheckIn checkIn, {
  DateTime? now,
}) {
  if (quotaCheckInFailed(slotKind: checkIn.slotKind, failed: checkIn.failed)) {
    return GoalCheckInOutcome.missed;
  }
  if (checkIn.logged) {
    return GoalCheckInOutcome.logged;
  }
  if (checkIn.isQuotaSlot && now != null) {
    final today = normalizeTaskListCalendarDay(now.toLocal());
    if (checkIn.timelineAt.isAfter(today)) {
      return GoalCheckInOutcome.pending;
    }
  }
  return GoalCheckInOutcome.pending;
}

/// Progress toward [goal.target] from logged check-ins.
///
/// Count goals (increasing): sum of [GoalCheckIn.countValue].
/// Count goals (decreasing): latest logged snapshot vs target.
/// Task goals: count of logged check-ins with completed == true.
/// Pulse goals: latest pulse_score / 10.
double computeGoalProgress(Goal goal, List<GoalCheckIn> checkIns) {
  final target = goal.target;
  if (target <= 0) return 0;

  switch (goal.goalType) {
    case GoalType.count:
      final increasing = goal.direction == GoalDirection.increasing;
      if (increasing) {
        num total = 0;
        for (final checkIn in checkIns) {
          if (!checkIn.logged || checkIn.countValue == null) continue;
          total += checkIn.countValue!;
        }
        return (total / target).clamp(0.0, 1.0).toDouble();
      }
      final current = _latestLoggedCountValue(checkIns);
      if (current == null) return 0;
      if (current <= target) return 1.0;
      final start = _earliestLoggedCountValue(checkIns) ?? current;
      if (start <= target) return (target / current).clamp(0.0, 1.0).toDouble();
      final span = start - target;
      if (span <= 0) return 0;
      return ((start - current) / span).clamp(0.0, 1.0).toDouble();
    case GoalType.task:
      final completed = checkIns
          .where((c) => c.logged && c.completed == true)
          .length;
      return (completed / target).clamp(0.0, 1.0).toDouble();
    case GoalType.pulse:
      GoalCheckIn? latest;
      for (final checkIn in checkIns) {
        if (!checkIn.logged || checkIn.pulseScore == null) continue;
        if (latest == null ||
            checkIn.checkInAt.isAfter(latest.checkInAt)) {
          latest = checkIn;
        }
      }
      if (latest?.pulseScore == null) return 0;
      return (latest!.pulseScore! / 10).clamp(0.0, 1.0).toDouble();
    default:
      return 0;
  }
}

/// Baseline value at the start of the goal journey (for current-vs-target progress).
num? computeGoalStartValue(Goal goal, List<GoalCheckIn> checkIns) {
  switch (goal.goalType) {
    case GoalType.count:
      if (goal.direction == GoalDirection.increasing) {
        return 0;
      }
      return _earliestLoggedCountValue(checkIns);
    case GoalType.task:
      return 0;
    case GoalType.pulse:
      final timeline = goalCheckInValueTimeline(goal, checkIns);
      return timeline.isEmpty ? null : timeline.first.value;
    default:
      return null;
  }
}

/// Latest measurable value for display (current vs target).
num? computeGoalCurrentValue(Goal goal, List<GoalCheckIn> checkIns) {
  switch (goal.goalType) {
    case GoalType.count:
      if (goal.direction == GoalDirection.decreasing) {
        return _latestLoggedCountValue(checkIns);
      }
      num total = 0;
      for (final checkIn in checkIns) {
        if (!checkIn.logged || checkIn.countValue == null) continue;
        total += checkIn.countValue!;
      }
      return total;
    case GoalType.task:
      return checkIns
          .where((c) => c.logged && c.completed == true)
          .length;
    case GoalType.pulse:
      GoalCheckIn? latest;
      for (final checkIn in checkIns) {
        if (!checkIn.logged || checkIn.pulseScore == null) continue;
        if (latest == null ||
            checkIn.checkInAt.isAfter(latest.checkInAt)) {
          latest = checkIn;
        }
      }
      return latest?.pulseScore;
    default:
      return null;
  }
}

num? _latestLoggedCountValue(List<GoalCheckIn> checkIns) {
  GoalCheckIn? latest;
  for (final checkIn in checkIns) {
    if (!checkIn.logged || checkIn.countValue == null) continue;
    if (latest == null || checkIn.checkInAt.isAfter(latest.checkInAt)) {
      latest = checkIn;
    }
  }
  return latest?.countValue;
}

num? _earliestLoggedCountValue(List<GoalCheckIn> checkIns) {
  GoalCheckIn? earliest;
  for (final checkIn in checkIns) {
    if (!checkIn.logged || checkIn.countValue == null) continue;
    if (earliest == null || checkIn.checkInAt.isBefore(earliest.checkInAt)) {
      earliest = checkIn;
    }
  }
  return earliest?.countValue;
}

/// Weekly rate of change from the two most recent logged value snapshots.
num? computeGoalVelocityPerWeek(Goal goal, List<GoalCheckIn> checkIns) {
  final timeline = goalCheckInValueTimeline(goal, checkIns);
  if (timeline.length < 2) return null;

  final previous = timeline[timeline.length - 2];
  final latest = timeline.last;
  final days = latest.at.difference(previous.at).inDays;
  if (days <= 0) return null;

  return (latest.value - previous.value) / (days / 7.0);
}

GoalPace computeGoalPace(
  Goal goal,
  double progressPercent, {
  DateTime? now,
}) {
  final end = goal.endDate;
  if (end == null) return GoalPace.unknown;

  final reference = now ?? DateTime.now();
  final startDay = normalizeTaskListCalendarDay(goal.startDate);
  final endDay = normalizeTaskListCalendarDay(end);
  final today = normalizeTaskListCalendarDay(reference);
  final totalDays = endDay.difference(startDay).inDays;
  if (totalDays <= 0) return GoalPace.unknown;

  final elapsedDays = today.difference(startDay).inDays.clamp(0, totalDays);
  if (elapsedDays <= 0) return GoalPace.unknown;

  final expectedProgress = elapsedDays / totalDays;
  final actualProgress = (progressPercent / 100).clamp(0.0, 1.0);
  final delta = actualProgress - expectedProgress;

  if (delta > 0.05) return GoalPace.ahead;
  if (delta < -0.05) return GoalPace.behind;
  return GoalPace.onTrack;
}

int? computeGoalEtaWeeks(
  Goal goal,
  num? currentValue,
  num? velocityPerWeek,
) {
  if (currentValue == null || velocityPerWeek == null || velocityPerWeek == 0) {
    return null;
  }

  final target = goal.target;
  if (goal.direction == GoalDirection.increasing) {
    final remaining = target - currentValue;
    if (remaining <= 0) return 0;
    if (velocityPerWeek <= 0) return null;
    return (remaining / velocityPerWeek).ceil();
  }

  final remaining = currentValue - target;
  if (remaining <= 0) return 0;
  if (velocityPerWeek >= 0) return null;
  return (remaining / velocityPerWeek.abs()).ceil();
}

/// Ring fill for ETA highlight: elapsed time ÷ (elapsed + remaining ETA).
double computeGoalEtaRingFraction(
  Goal goal,
  int? etaWeeks, {
  DateTime? now,
}) {
  if (etaWeeks == null) return 0;
  if (etaWeeks <= 0) return 1;

  final reference = now ?? DateTime.now();
  final elapsedDays = reference.difference(goal.startDate).inDays;
  if (elapsedDays <= 0) return 0;

  final elapsedWeeks = elapsedDays / 7.0;
  final totalWeeks = elapsedWeeks + etaWeeks;
  if (totalWeeks <= 0) return 0;
  return (elapsedWeeks / totalWeeks).clamp(0.0, 1.0).toDouble();
}

/// Ring fill for the current-vs-target highlight card (start → target).
double computeCurrentTargetRingFraction(
  Goal goal, {
  num? startValue,
  num? currentValue,
}) {
  if (currentValue == null || goal.target <= 0) return 0;

  final target = goal.target;
  final start = startValue ?? 0;

  if (goal.goalType == GoalType.count &&
      goal.direction == GoalDirection.decreasing) {
    final span = start - target;
    if (span <= 0) return currentValue <= target ? 1.0 : 0;
    return ((start - currentValue) / span).clamp(0.0, 1.0).toDouble();
  }

  final span = target - start;
  if (span <= 0) return currentValue >= target ? 1.0 : 0;
  return ((currentValue - start) / span).clamp(0.0, 1.0).toDouble();
}

typedef GoalValuePoint = ({DateTime at, num value});

/// Logged check-in values over time (cumulative for increasing count / task goals).
List<GoalValuePoint> goalCheckInValueTimeline(
  Goal goal,
  List<GoalCheckIn> checkIns,
) {
  final logged = checkIns.where((c) => c.logged).toList()
    ..sort((a, b) => a.checkInAt.compareTo(b.checkInAt));

  switch (goal.goalType) {
    case GoalType.count:
      if (goal.direction == GoalDirection.increasing) {
        num running = 0;
        final timeline = <({DateTime at, num value})>[];
        for (final checkIn in logged) {
          if (checkIn.countValue == null) continue;
          running += checkIn.countValue!;
          timeline.add((at: checkIn.checkInAt, value: running));
        }
        return timeline;
      }
      return [
        for (final checkIn in logged)
          if (checkIn.countValue != null)
            (at: checkIn.checkInAt, value: checkIn.countValue!),
      ];
    case GoalType.task:
      var completed = 0;
      return [
        for (final checkIn in logged)
          (
            at: checkIn.checkInAt,
            value: completed += checkIn.completed == true ? 1 : 0,
          ),
      ];
    case GoalType.pulse:
      return [
        for (final checkIn in logged)
          if (checkIn.pulseScore != null)
            (at: checkIn.checkInAt, value: checkIn.pulseScore!),
      ];
    default:
      return const [];
  }
}

/// Time window for the goal value chart.
enum GoalValueChartRange {
  days7,
  days30,
  days90,
  all,
}

extension GoalValueChartRangeLabels on GoalValueChartRange {
  String get label => switch (this) {
        GoalValueChartRange.days7 => '7d',
        GoalValueChartRange.days30 => '30d',
        GoalValueChartRange.days90 => '90d',
        GoalValueChartRange.all => 'All',
      };

  Duration? get duration => switch (this) {
        GoalValueChartRange.days7 => const Duration(days: 7),
        GoalValueChartRange.days30 => const Duration(days: 30),
        GoalValueChartRange.days90 => const Duration(days: 90),
        GoalValueChartRange.all => null,
      };
}

List<GoalValuePoint> filterGoalValueTimeline(
  List<GoalValuePoint> timeline,
  GoalValueChartRange range,
  DateTime listToday,
) {
  if (range == GoalValueChartRange.all || timeline.isEmpty) {
    return timeline;
  }
  final duration = range.duration;
  if (duration == null) return timeline;

  final cutoff = normalizeTaskListCalendarDay(listToday).subtract(duration);
  return [
    for (final point in timeline)
      if (!normalizeTaskListCalendarDay(point.at).isBefore(cutoff)) point,
  ];
}

String goalValueOverTimeTitle(Goal goal) => switch (goal.goalType) {
      GoalType.pulse => 'Score over time',
      GoalType.task => 'Completion over time',
      GoalType.count => _countValueOverTimeTitle(goal),
      _ => 'Progress over time',
    };

String _countValueOverTimeTitle(Goal goal) {
  final unit = goal.unit.trim();
  if (unit.isEmpty) return 'Value over time';
  if (unit.length == 1) {
    return '${unit.toUpperCase()} over time';
  }
  return '${unit[0].toUpperCase()}${unit.substring(1)} over time';
}

String formatGoalChartValue(num value, Goal goal) {
  final unit = goal.unit.trim();
  final rounded = value.roundToDouble();
  final text = rounded == value
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  if (unit.isEmpty) return text;
  return '$text $unit';
}

String goalValueOverTimeSubtitle(Goal goal, GoalStats stats) {
  final start = stats.startValue;
  final target = goal.target;
  if (start == null) {
    return '${formatGoalChartValue(target, goal)} target';
  }
  return '${formatGoalChartValue(start, goal)} start → '
      '${formatGoalChartValue(target, goal)} target';
}

/// Position on the start→target progress bar (0 = start, 1 = target).
double goalValueProgressFraction(
  Goal goal, {
  required num startValue,
  required num value,
}) {
  final target = goal.target;
  if (goal.goalType == GoalType.count &&
      goal.direction == GoalDirection.decreasing) {
    final span = startValue - target;
    if (span <= 0) return value <= target ? 1.0 : 0;
    return ((startValue - value) / span).clamp(0.0, 1.0).toDouble();
  }

  final span = target - startValue;
  if (span <= 0) return value >= target ? 1.0 : 0;
  return ((value - startValue) / span).clamp(0.0, 1.0).toDouble();
}

class GoalProgressBarMarker {
  const GoalProgressBarMarker({
    required this.fraction,
    required this.value,
    this.suffix,
  });

  final double fraction;
  final num value;
  final String? suffix;
}

List<GoalProgressBarMarker> buildGoalProgressBarMarkers(
  Goal goal,
  GoalStats stats,
) {
  if (goal.target <= 0) return const [];

  final start = stats.startValue;
  if (start == null && goal.goalType != GoalType.count) return const [];
  if (start == null &&
      goal.goalType == GoalType.count &&
      goal.direction == GoalDirection.decreasing) {
    return const [];
  }

  final resolvedStart = start ?? 0;
  final target = goal.target;
  final current = stats.currentValue;

  bool matchesValue(num a, num b) => (a - b).abs() < 0.0001;

  final markers = <GoalProgressBarMarker>[];

  void addMarker(num value, String? suffix) {
    markers.add(
      GoalProgressBarMarker(
        fraction: goalValueProgressFraction(
          goal,
          startValue: resolvedStart,
          value: value,
        ),
        value: value,
        suffix: suffix,
      ),
    );
  }

  addMarker(resolvedStart, null);

  final milestones = List<GoalMilestone>.from(goal.milestones)
    ..sort((a, b) {
      if (goal.direction == GoalDirection.decreasing) {
        return b.value.compareTo(a.value);
      }
      return a.value.compareTo(b.value);
    });

  for (final milestone in milestones) {
    if (matchesValue(milestone.value, resolvedStart) ||
        matchesValue(milestone.value, target)) {
      continue;
    }
    if (current != null && matchesValue(milestone.value, current)) {
      continue;
    }
    addMarker(milestone.value, null);
  }

  if (current != null &&
      !matchesValue(current, resolvedStart) &&
      !matchesValue(current, target)) {
    addMarker(current, 'now');
  }

  addMarker(target, null);

  markers.sort((a, b) => a.fraction.compareTo(b.fraction));
  return markers;
}

GoalStats computeGoalStats(
  Goal goal,
  List<GoalCheckIn> checkIns, {
  DateTime? now,
}) {
  if (checkIns.isEmpty) {
    final reference = now ?? DateTime.now();
    final consistency = _computeGoalConsistency(
      dayOutcomes: const {},
      goalStart: goal.startDate,
      goalEnd: goal.endDate,
      reference: reference,
    );
    final progressPercent = computeGoalProgress(goal, checkIns) * 100;
    return GoalStats.empty.copyWith(
      progressPercent: progressPercent,
      consistency: consistency.rate,
      consistencyLogged: consistency.logged,
      consistencyScheduled: consistency.scheduled,
      unitLabel: goal.goalType == GoalType.count ? goal.unit.trim() : null,
      currentValue: computeGoalCurrentValue(goal, checkIns),
      startValue: computeGoalStartValue(goal, checkIns),
      pace: computeGoalPace(goal, progressPercent, now: reference),
    );
  }

  final reference = now ?? DateTime.now();
  final sorted = [...checkIns]
    ..sort((a, b) => a.checkInAt.compareTo(b.checkInAt));

  final evaluated = sorted
      .map(
        (checkIn) => _EvaluatedGoalCheckIn(
          checkIn: checkIn,
          outcome: classifyGoalCheckIn(checkIn, now: reference),
        ),
      )
      .toList();

  final logged =
      evaluated.where((e) => e.outcome == GoalCheckInOutcome.logged).length;
  final pending =
      evaluated.where((e) => e.outcome == GoalCheckInOutcome.pending).length;

  final dayOutcomes = _rollupDayOutcomes(evaluated);
  final weeklyTrend = _weeklyTrend(evaluated, reference);
  final consistency = _computeGoalConsistency(
    dayOutcomes: dayOutcomes,
    goalStart: goal.startDate,
    goalEnd: goal.endDate,
    reference: reference,
  );

  num totalUnits = 0;
  var completedPeriods = 0;
  if (goal.goalType == GoalType.count) {
    for (final item in evaluated) {
      if (item.outcome == GoalCheckInOutcome.logged &&
          item.checkIn.countValue != null) {
        totalUnits += item.checkIn.countValue!;
      }
    }
  } else if (goal.goalType == GoalType.task) {
    completedPeriods = evaluated
        .where(
          (e) =>
              e.outcome == GoalCheckInOutcome.logged &&
              e.checkIn.completed == true,
        )
        .length;
  }

  return GoalStats(
    progressPercent: computeGoalProgress(goal, checkIns) * 100,
    currentStreak: _currentStreak(dayOutcomes, reference),
    bestStreak: _bestStreak(dayOutcomes),
    totalScheduled: evaluated.length,
    loggedCount: logged,
    pendingCount: pending,
    consistency: consistency.rate,
    consistencyLogged: consistency.logged,
    consistencyScheduled: consistency.scheduled,
    dayOutcomes: dayOutcomes,
    weeklyLoggedRates: weeklyTrend.rates,
    weeklyHasData: weeklyTrend.hasData,
    totalUnitsLogged: totalUnits,
    completedPeriods: completedPeriods,
    unitLabel: goal.goalType == GoalType.count ? goal.unit.trim() : null,
    currentValue: computeGoalCurrentValue(goal, checkIns),
    startValue: computeGoalStartValue(goal, checkIns),
    velocityPerWeek: computeGoalVelocityPerWeek(goal, checkIns),
    pace: computeGoalPace(
      goal,
      computeGoalProgress(goal, checkIns) * 100,
      now: reference,
    ),
    etaWeeks: computeGoalEtaWeeks(
      goal,
      computeGoalCurrentValue(goal, checkIns),
      computeGoalVelocityPerWeek(goal, checkIns),
    ),
  );
}

extension on GoalStats {
  GoalStats copyWith({
    double? progressPercent,
    double? consistency,
    int? consistencyLogged,
    int? consistencyScheduled,
    String? unitLabel,
    num? currentValue,
    num? startValue,
    GoalPace? pace,
  }) {
    return GoalStats(
      progressPercent: progressPercent ?? this.progressPercent,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalScheduled: totalScheduled,
      loggedCount: loggedCount,
      pendingCount: pendingCount,
      consistency: consistency ?? this.consistency,
      consistencyLogged: consistencyLogged ?? this.consistencyLogged,
      consistencyScheduled: consistencyScheduled ?? this.consistencyScheduled,
      dayOutcomes: dayOutcomes,
      weeklyLoggedRates: weeklyLoggedRates,
      weeklyHasData: weeklyHasData,
      totalUnitsLogged: totalUnitsLogged,
      completedPeriods: completedPeriods,
      unitLabel: unitLabel ?? this.unitLabel,
      currentValue: currentValue ?? this.currentValue,
      startValue: startValue ?? this.startValue,
      velocityPerWeek: velocityPerWeek,
      pace: pace ?? this.pace,
      etaWeeks: etaWeeks,
    );
  }
}

({double rate, int logged, int scheduled}) _computeGoalConsistency({
  required Map<DateTime, GoalDayOutcome> dayOutcomes,
  required DateTime goalStart,
  required DateTime? goalEnd,
  required DateTime reference,
  int windowSize = 30,
}) {
  final start = normalizeTaskListCalendarDay(goalStart);
  final today = normalizeTaskListCalendarDay(reference);
  final rangeEnd =
      goalEnd != null ? normalizeTaskListCalendarDay(goalEnd) : today;
  final effectiveEnd = rangeEnd.isBefore(today) ? rangeEnd : today;
  if (effectiveEnd.isBefore(start)) {
    return (rate: 0.0, logged: 0, scheduled: 0);
  }

  final scheduledDays = <DateTime>[];
  for (var day = start;
      !day.isAfter(effectiveEnd);
      day = day.add(const Duration(days: 1))) {
    final outcome = dayOutcomes[day];
    if (day == today && outcome == GoalDayOutcome.pending) continue;
    scheduledDays.add(day);
  }

  final window = scheduledDays.length > windowSize
      ? scheduledDays.sublist(scheduledDays.length - windowSize)
      : scheduledDays;
  if (window.isEmpty) {
    return (rate: 0.0, logged: 0, scheduled: 0);
  }

  var logged = 0;
  for (final day in window) {
    if (dayOutcomes[day] == GoalDayOutcome.logged) {
      logged++;
    }
  }

  return (
    rate: logged / window.length,
    logged: logged,
    scheduled: window.length,
  );
}

Map<DateTime, GoalDayOutcome> _rollupDayOutcomes(
  List<_EvaluatedGoalCheckIn> evaluated,
) {
  final byDay = <DateTime, List<GoalCheckInOutcome>>{};
  for (final item in evaluated) {
    final key = item.checkIn.timelineAt;
    byDay.putIfAbsent(key, () => []).add(item.outcome);
  }

  final result = <DateTime, GoalDayOutcome>{};
  for (final entry in byDay.entries) {
    final outcomes = entry.value;
    if (outcomes.contains(GoalCheckInOutcome.logged)) {
      result[entry.key] = GoalDayOutcome.logged;
    } else if (outcomes.contains(GoalCheckInOutcome.missed)) {
      result[entry.key] = GoalDayOutcome.missed;
    } else {
      result[entry.key] = GoalDayOutcome.pending;
    }
  }
  return result;
}

int _currentStreak(
  Map<DateTime, GoalDayOutcome> dayOutcomes,
  DateTime reference,
) {
  var streak = 0;
  var day = normalizeTaskListCalendarDay(reference);
  final start = day.subtract(const Duration(days: 365 * 5));

  while (!day.isBefore(start)) {
    final outcome = dayOutcomes[day];
    if (outcome == GoalDayOutcome.logged) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    } else if (outcome == GoalDayOutcome.pending && day == reference) {
      day = day.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }
  return streak;
}

int _bestStreak(Map<DateTime, GoalDayOutcome> dayOutcomes) {
  if (dayOutcomes.isEmpty) return 0;

  final days = dayOutcomes.keys.toList()..sort();
  var best = 0;
  var current = 0;
  DateTime? previous;

  for (final day in days) {
    if (dayOutcomes[day] == GoalDayOutcome.logged) {
      if (previous != null &&
          day.difference(previous).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > best) best = current;
      previous = day;
    } else {
      current = 0;
      previous = day;
    }
  }
  return best;
}

({List<double> rates, List<bool> hasData}) _weeklyTrend(
  List<_EvaluatedGoalCheckIn> evaluated,
  DateTime reference,
) {
  final currentWeekStart = taskListWeekStart(reference);
  final rates = <double>[];
  final hasData = <bool>[];

  for (var offset = 7; offset >= 0; offset--) {
    final weekStart = currentWeekStart.subtract(Duration(days: 7 * offset));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekItems = evaluated.where((e) {
      final local = e.checkIn.timelineAt;
      return !local.isBefore(weekStart) && local.isBefore(weekEnd);
    });
    final logged = weekItems
        .where((e) => e.outcome == GoalCheckInOutcome.logged)
        .length;
    final total = weekItems.length;
    rates.add(total == 0 ? 0.0 : logged / total);
    hasData.add(total > 0);
  }
  return (rates: rates, hasData: hasData);
}

GoalDayOutcome? goalDayOutcomeOn(
  Map<DateTime, GoalDayOutcome> dayOutcomes,
  DateTime day,
) {
  return dayOutcomes[normalizeTaskListCalendarDay(day)];
}
