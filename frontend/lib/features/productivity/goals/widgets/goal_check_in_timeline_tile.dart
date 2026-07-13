import 'package:flutter/material.dart';
import 'package:frontend/core/icons/companion_task_field_icon.dart';
import 'package:frontend/core/icons/companion_task_field_icons.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/outcome_colors.dart';
import 'package:frontend/features/productivity/tasks/forms/task_field_option_tile.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';

import 'package:frontend/features/productivity/goals/services/goal_list_actions.dart';
import 'package:frontend/features/productivity/goals/services/goal_stats.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_display.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';

String goalCheckInOutcomeLabel(GoalCheckInOutcome outcome) =>
    switch (outcome) {
      GoalCheckInOutcome.logged => 'Logged',
      GoalCheckInOutcome.pending => 'Pending',
      GoalCheckInOutcome.missed => 'Failed',
    };

Color goalCheckInOutcomeColor(
  GoalCheckInOutcome outcome,
  ColorScheme scheme,
) =>
    switch (outcome) {
      GoalCheckInOutcome.logged => companionSuccessColor,
      GoalCheckInOutcome.pending => taskStatusColor('pending', scheme),
      GoalCheckInOutcome.missed => trackerStrengthLowColor,
    };

IconData goalCheckInOutcomeIcon(GoalCheckInOutcome outcome) =>
    switch (outcome) {
      GoalCheckInOutcome.logged => Icons.check_circle_outline,
      GoalCheckInOutcome.pending => Icons.schedule,
      GoalCheckInOutcome.missed => Icons.cancel_outlined,
    };

String? goalCheckInValueSummary(Goal goal, GoalCheckIn checkIn) {
  if (!checkIn.logged) return null;
  return switch (goal.goalType) {
    GoalType.count =>
      checkIn.countValue != null ? '${checkIn.countValue} ${goal.unit.trim()}' : null,
    GoalType.task => checkIn.completed == true ? 'Completed' : 'Not completed',
    GoalType.pulse =>
      checkIn.pulseScore != null ? 'Pulse ${checkIn.pulseScore}/10' : null,
    _ => null,
  };
}

class GoalTimelineOutcomeButton extends StatelessWidget {
  const GoalTimelineOutcomeButton({
    super.key,
    required this.goal,
    required this.checkIn,
    required this.outcome,
    required this.color,
    this.onPressed,
    this.onLongPress,
    this.enabled = true,
    this.actionEnabled = true,
  });

  final Goal goal;
  final GoalCheckIn checkIn;
  final GoalCheckInOutcome outcome;
  final Color color;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool actionEnabled;

  String get _tooltip => switch (goal.goalType) {
        GoalType.task => 'Toggle logged',
        GoalType.count => 'Log count',
        GoalType.pulse => 'Read only',
        _ => 'Check in',
      };

  @override
  Widget build(BuildContext context) {
    final size = CompanionFormStyles.taskTimelineNodeSize;
    final canTap = enabled && actionEnabled && onPressed != null;
    final canLongPress = enabled && onLongPress != null;

    return IconButton(
      tooltip: _tooltip,
      onPressed: canTap
          ? onPressed
          : canLongPress
              ? () {}
              : null,
      onLongPress: canLongPress ? onLongPress : null,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: color.withValues(alpha: 0.38),
      ),
      constraints: BoxConstraints.tightFor(width: size + 8, height: size + 8),
      icon: companionTaskFieldIcon(
        iconData: goalCheckInOutcomeIcon(outcome),
        iconName: outcome == GoalCheckInOutcome.logged
            ? TaskFieldIconNames.statusCompleted
            : TaskFieldIconNames.statusPending,
        size: CompanionFormStyles.taskTimelineIconSize,
        color: color,
      ),
    );
  }
}

class GoalCheckInTimelineTile extends StatefulWidget {
  const GoalCheckInTimelineTile({
    super.key,
    required this.goal,
    required this.checkIn,
    required this.actions,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
    this.onOutcomePressed,
    this.onOutcomeLongPress,
    this.outcomeToggleEnabled = true,
    this.hideLeadingIcon = false,
  });

  final Goal goal;
  final GoalCheckIn checkIn;
  final GoalListTileActions actions;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final VoidCallback? onOutcomePressed;
  final VoidCallback? onOutcomeLongPress;
  final bool outcomeToggleEnabled;
  final bool hideLeadingIcon;

  @override
  State<GoalCheckInTimelineTile> createState() =>
      _GoalCheckInTimelineTileState();
}

class _GoalCheckInTimelineTileState extends State<GoalCheckInTimelineTile> {
  bool _busy = false;

  Goal get goal => widget.goal;
  GoalCheckIn get checkIn => widget.checkIn;

  bool _canInteractWithOutcome(GoalCheckInOutcome outcome) {
    if (goal.goalType == GoalType.pulse) return false;
    if (outcome == GoalCheckInOutcome.missed) return false;
    if (widget.onOutcomePressed == null && widget.onOutcomeLongPress == null) {
      return false;
    }
    if (checkIn.checkInAt.isAfter(DateTime.now())) return false;
    return true;
  }

  bool _outcomeTapEnabled() {
    if (goal.goalType == GoalType.pulse) return false;
    if (checkIn.checkInAt.isAfter(DateTime.now())) return false;
    return goal.goalType == GoalType.task;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final outcome = classifyGoalCheckIn(checkIn, now: DateTime.now());
    final outcomeColor = goalCheckInOutcomeColor(outcome, scheme);
    final goalColor = parseGoalColor(goal.color, scheme.primary) ?? scheme.primary;
    final valueSummary = goalCheckInValueSummary(goal, checkIn);
    final tileOpacity = _busy ? 0.6 : 1.0;

    final statusNode = _canInteractWithOutcome(outcome)
        ? GoalTimelineOutcomeButton(
            goal: goal,
            checkIn: checkIn,
            outcome: outcome,
            color: outcomeColor,
            enabled: widget.outcomeToggleEnabled,
            actionEnabled: _outcomeTapEnabled(),
            onPressed: widget.onOutcomePressed,
            onLongPress: widget.onOutcomeLongPress,
          )
        : Icon(
            goalCheckInOutcomeIcon(outcome),
            size: CompanionFormStyles.taskTimelineIconSize,
            color: outcomeColor,
          );

    return Opacity(
      opacity: tileOpacity,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: CompanionFormStyles.taskRowVerticalGap,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskTimelineColumn(
                isFirst: widget.isFirst,
                isLast: widget.isLast,
                statusNode: statusNode,
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _busy ? null : widget.onTap,
                    onLongPress: _busy ? null : widget.onLongPress,
                    borderRadius: BorderRadius.circular(
                      CompanionFormStyles.taskRowPanelRadius,
                    ),
                    child: TaskRowPanel(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!widget.hideLeadingIcon) ...[
                            TaskTimelineIconBadge(
                              color: goalColor,
                              iconName: goal.icon,
                              defaultIconName: TaskCategoryChipDefaults.goalIcon,
                              materialFallback: Icons.flag_outlined,
                            ),
                            const SizedBox(
                              width: CompanionFormStyles.taskPanelIconBadgeGap,
                            ),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: CompanionFormStyles.taskListChipGap,
                                  runSpacing:
                                      CompanionFormStyles.taskListChipGap,
                                  children: [
                                    TaskMetaChip(
                                      label: goalTypeLabel(goal.goalType),
                                      tintColor: scheme.primary,
                                      leading: Icon(
                                        goalTypeIcon(goal.goalType),
                                        size: 14,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    TaskMetaChip(
                                      label: goalCheckInOutcomeLabel(outcome),
                                      tintColor: outcomeColor,
                                      leading: Icon(
                                        goalCheckInOutcomeIcon(outcome),
                                        size: 14,
                                        color: outcomeColor,
                                      ),
                                    ),
                                    if (valueSummary != null)
                                      TaskMetaChip(
                                        label: valueSummary,
                                        tintColor: goalColor,
                                      ),
                                  ],
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
