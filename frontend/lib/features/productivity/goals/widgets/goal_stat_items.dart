import 'package:flutter/material.dart';

import 'package:frontend/core/theme/companion_semantic_colors.dart';

import 'package:frontend/features/productivity/models/productivity_record.dart';

import 'package:frontend/features/productivity/goals/services/goal_stats.dart';



class GoalStatItem {

  const GoalStatItem(

    this.label,

    this.value, {

    this.valueColor,

  });



  final String label;

  final String value;

  final Color? valueColor;

}



List<GoalStatItem> buildGoalStatItems({

  required Goal goal,

  required GoalStats stats,

}) {

  final items = <GoalStatItem>[

    GoalStatItem('Current streak', '${stats.currentStreak} days'),

    GoalStatItem('Best streak', '${stats.bestStreak} days'),

    GoalStatItem('Scheduled moments', '${stats.totalScheduled}'),

    GoalStatItem('Logged', '${stats.loggedCount}'),

    GoalStatItem('Pending', '${stats.pendingCount}'),

    GoalStatItem(

      'Progress',

      '${stats.progressPercent.round()}%',

    ),

  ];



  if (goal.goalType == GoalType.count) {

    final unit = stats.unitLabel ?? 'units';

    items.add(

      GoalStatItem('Logged $unit', _formatNum(stats.totalUnitsLogged)),

    );

  } else if (goal.goalType == GoalType.task) {

    items.add(

      GoalStatItem('Completed periods', '${stats.completedPeriods}'),

    );

  }



  return items;

}



List<GoalStatItem> buildGoalSidebarStatItems({

  required Goal goal,

  required GoalStats stats,

}) {

  return [
    GoalStatItem('Total check-ins', '${stats.loggedCount}'),
    GoalStatItem('Velocity', formatGoalVelocity(goal, stats.velocityPerWeek)),
    GoalStatItem('ETA', formatGoalEta(stats.etaWeeks)),
    GoalStatItem(
      'Pace',
      formatGoalPace(stats.pace),
      valueColor: goalPaceColor(stats.pace),
    ),
  ];

}



String formatGoalCurrentTarget(Goal goal, GoalStats stats) {
  final start = stats.startValue;
  final current = stats.currentValue;
  final target = goal.target;

  final startLabel = start == null ? '—' : _formatNum(start);
  final currentLabel = current == null ? '—' : _formatNum(current);
  final targetLabel = _formatNum(target);

  if (goal.goalType == GoalType.count) {
    final unit = goal.unit.trim();
    if (unit.isNotEmpty) {
      if (start != null && goal.direction == GoalDirection.decreasing) {
        return '$startLabel → $currentLabel / $targetLabel $unit';
      }
      return '$currentLabel / $targetLabel $unit';
    }
  } else if (goal.goalType == GoalType.pulse) {
    if (start != null) {
      return '$startLabel → $currentLabel / $targetLabel';
    }
    return '$currentLabel / $targetLabel';
  } else if (goal.goalType == GoalType.task) {
    return '$currentLabel / $targetLabel';
  }

  return '$currentLabel / $targetLabel';
}



String formatGoalVelocity(Goal goal, num? velocityPerWeek) {

  if (velocityPerWeek == null) return '—';



  final magnitude = velocityPerWeek.abs();

  final formatted = magnitude < 10

      ? velocityPerWeek.toStringAsFixed(1)

      : velocityPerWeek.round().toString();



  if (goal.goalType == GoalType.count) {

    final unit = goal.unit.trim();

    if (unit.isNotEmpty) {

      return '$formatted $unit/wk';

    }

  }



  return '$formatted/wk';

}



String formatGoalPace(GoalPace pace) => switch (pace) {

      GoalPace.ahead => 'Ahead',

      GoalPace.onTrack => 'On track',

      GoalPace.behind => 'Behind',

      GoalPace.unknown => '—',

    };



Color? goalPaceColor(GoalPace pace) => switch (pace) {

      GoalPace.ahead => companionSuccessColor,

      GoalPace.behind => companionUrgentColor,

      GoalPace.onTrack => null,

      GoalPace.unknown => null,

    };



String formatGoalEta(int? etaWeeks) {
  if (etaWeeks == null) return '—';
  if (etaWeeks <= 0) return 'Reached';
  if (etaWeeks == 1) return '~1 week';
  return '~$etaWeeks weeks';
}

/// Compact ETA label for sidebar highlight cards (e.g. `~9 wks`).
String formatGoalEtaShort(int? etaWeeks) {
  if (etaWeeks == null) return '—';
  if (etaWeeks <= 0) return 'Reached';
  if (etaWeeks == 1) return '~1 wk';
  return '~$etaWeeks wks';
}



String _formatNum(num value) {

  if (value == value.roundToDouble()) {

    return value.round().toString();

  }

  return value.toStringAsFixed(1);

}


