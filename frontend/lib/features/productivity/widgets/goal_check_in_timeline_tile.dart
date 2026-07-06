import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/task_field_option_tile.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/goal_check_in.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/check_in_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

enum GoalCheckInOutcome {
  pending,
  succeeded,
  missed,
}

GoalCheckInOutcome classifyGoalCheckIn(
  Goal goal,
  GoalCheckIn checkIn, {
  required DateTime now,
}) {
  if (checkIn.slotKind == CheckInSlotKind.periodMiss) {
    return GoalCheckInOutcome.missed;
  }
  if (checkIn.displayAtFor(goal, now: now).isAfter(now)) {
    return GoalCheckInOutcome.pending;
  }
  if (!checkIn.logged) {
    return GoalCheckInOutcome.pending;
  }
  if (goal.goalType == GoalType.task) {
    return checkIn.completed == true
        ? GoalCheckInOutcome.succeeded
        : GoalCheckInOutcome.missed;
  }
  if (goal.goalType == GoalType.count) {
    final value = checkIn.countValue ?? 0;
    return goal.direction == GoalDirection.increasing
        ? (value > 0 ? GoalCheckInOutcome.succeeded : GoalCheckInOutcome.missed)
        : GoalCheckInOutcome.succeeded;
  }
  return GoalCheckInOutcome.pending;
}

String goalCheckInOutcomeLabel(GoalCheckInOutcome outcome) => switch (outcome) {
      GoalCheckInOutcome.pending => 'Pending',
      GoalCheckInOutcome.succeeded => 'Done',
      GoalCheckInOutcome.missed => 'Missed',
    };

Color goalCheckInOutcomeColor(GoalCheckInOutcome outcome, ColorScheme scheme) =>
    switch (outcome) {
      GoalCheckInOutcome.succeeded => trackerStrengthHighColor,
      GoalCheckInOutcome.missed => trackerStrengthLowColor,
      GoalCheckInOutcome.pending => taskStatusColor('pending', scheme),
    };

IconData goalCheckInOutcomeIcon(GoalCheckInOutcome outcome) => switch (outcome) {
      GoalCheckInOutcome.succeeded => Icons.check_circle_outline,
      GoalCheckInOutcome.missed => Icons.cancel_outlined,
      GoalCheckInOutcome.pending => Icons.schedule,
    };

/// Timeline row for a materialized goal check-in moment.
class GoalCheckInTimelineTile extends StatelessWidget {
  const GoalCheckInTimelineTile({
    super.key,
    required this.goal,
    required this.checkIn,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    this.onOutcomePressed,
    this.outcomeToggleEnabled = true,
  });

  final Goal goal;
  final GoalCheckIn checkIn;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback? onOutcomePressed;
  final bool outcomeToggleEnabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final outcome = classifyGoalCheckIn(goal, checkIn, now: now);
    final color = goalCheckInOutcomeColor(outcome, scheme);
    final canPress = outcomeToggleEnabled &&
        onOutcomePressed != null &&
        !checkIn.displayAtFor(goal, now: now).isAfter(now);

    final statusNode = IconButton(
      tooltip: goal.goalType == GoalType.count ? 'Log progress' : 'Toggle done',
      onPressed: canPress ? onOutcomePressed : null,
      padding: EdgeInsets.zero,
      icon: Icon(
        goalCheckInOutcomeIcon(outcome),
        color: color,
        size: CompanionFormStyles.taskTimelineIconSize,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(
        bottom: CompanionFormStyles.taskRowVerticalGap,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaskTimelineColumn(
              isFirst: isFirst,
              isLast: isLast,
              statusNode: statusNode,
            ),
            Expanded(
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goal.usesQuotaMode && goal.quotaTimes != null
                              ? '${goalCheckInOutcomeLabel(outcome)} · quota check-in'
                              : goalCheckInOutcomeLabel(outcome),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
