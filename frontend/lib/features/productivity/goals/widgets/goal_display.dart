import 'package:flutter/material.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/core/ui/outcome_colors.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';

import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

const goalMilestoneChipColor = companionMilestoneColor;

String goalTypeLabel(String value) => switch (value) {
      GoalType.count => 'Count',
      GoalType.task => 'Task',
      GoalType.pulse => 'Pulse',
      _ => value,
    };

String goalDirectionLabel(String value) => switch (value) {
      GoalDirection.increasing => 'Increasing',
      GoalDirection.decreasing => 'Decreasing',
      _ => value,
    };

String goalTargetSummary(Goal goal) {
  final unit = goal.unit.trim();
  if (unit.isNotEmpty) {
    return '${goal.target} $unit';
  }
  return goal.target.toString();
}

String goalSubtitle(Goal goal) {
  final parts = <String>[
    goalTypeLabel(goal.goalType),
    goalTargetSummary(goal),
    goalDirectionLabel(goal.direction),
  ];
  if (goal.milestoneCount > 0) {
    parts.add(
      '${goal.milestoneCount} milestone${goal.milestoneCount == 1 ? '' : 's'}',
    );
  }
  final dateLabel = trackerDateRangeLabel(goal.startDate, goal.endDate);
  if (dateLabel != null) {
    parts.add(dateLabel);
  }
  return parts.join(' · ');
}

Color? parseGoalColor(String? hex, Color fallback) =>
    parseProjectColor(hex, fallback);

String goalTypeTargetChipLabel(Goal goal) => switch (goal.goalType) {
      GoalType.count => goalTargetSummary(goal),
      GoalType.task => 'Task',
      GoalType.pulse => 'Pulse',
      _ => goalTypeLabel(goal.goalType),
    };

IconData goalTypeIcon(String goalType) => switch (goalType) {
      GoalType.count => Icons.numbers_outlined,
      GoalType.task => Icons.check_circle_outline,
      GoalType.pulse => Icons.favorite_outline,
      _ => Icons.flag_outlined,
    };

IconData goalDirectionIcon(String direction) => switch (direction) {
      GoalDirection.increasing => Icons.trending_up,
      GoalDirection.decreasing => Icons.trending_down,
      _ => Icons.trending_flat,
    };

Color goalDirectionColor(String direction, ColorScheme scheme) =>
    switch (direction) {
      GoalDirection.increasing => companionSuccessColor,
      GoalDirection.decreasing => scheme.error,
      _ => scheme.onSurface.withValues(alpha: 0.55),
    };

String formatGoalStreakLabel(int currentStreak, {bool compact = false}) {
  if (currentStreak <= 0) {
    return compact ? '0d' : '0 day streak';
  }
  if (compact) {
    return '${currentStreak}d';
  }
  return '$currentStreak day${currentStreak == 1 ? '' : 's'} streak';
}

Color goalProgressColor(double progressPercent) {
  if (progressPercent >= 75) return trackerStrengthHighColor;
  if (progressPercent >= 40) return trackerStrengthMidColor;
  return trackerStrengthLowColor;
}
