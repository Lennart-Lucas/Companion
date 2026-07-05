import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/widgets/project_display.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

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
