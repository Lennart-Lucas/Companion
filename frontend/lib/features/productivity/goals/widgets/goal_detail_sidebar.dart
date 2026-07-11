import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';

import 'package:frontend/features/productivity/goals/services/goal_stats.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_display.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_health_overview_section.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_sidebar_stats_list.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_stats_highlight_row.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class GoalDetailSidebar extends StatelessWidget {
  const GoalDetailSidebar({
    super.key,
    required this.goal,
    required this.stats,
    required this.listToday,
  });

  static const width = 380.0;

  final Goal goal;
  final GoalStats stats;
  final DateTime listToday;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GoalDetailHeader(
              goal: goal,
              progressPercent: stats.progressPercent,
            ),
            const SizedBox(height: 16),
            GoalStatsHighlightRow(
              goal: goal,
              stats: stats,
              layout: GoalStatsHighlightLayout.vertical,
            ),
            const SizedBox(height: 20),
            GoalSidebarStatsList(
              goal: goal,
              stats: stats,
            ),
            const SizedBox(height: 20),
            GoalHealthOverviewSection(
              goal: goal,
              stats: stats,
              listToday: listToday,
            ),
          ],
        ),
      ),
    );
  }
}

class GoalDetailHeader extends StatelessWidget {
  const GoalDetailHeader({
    super.key,
    required this.goal,
    required this.progressPercent,
  });

  final Goal goal;
  final double progressPercent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final directionColor = goalDirectionColor(goal.direction, scheme);
    final description = goal.description?.trim();
    final dateLabel = trackerDateRangeLabel(goal.startDate, goal.endDate);
    final typeTargetLabel = goalTypeTargetChipLabel(goal);

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (description != null && description.isNotEmpty) ...[
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: CompanionFormStyles.taskListChipGap,
            runSpacing: CompanionFormStyles.taskListChipGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TaskMetaChip(
                label: typeTargetLabel,
                tintColor: scheme.primary,
                leading: Icon(
                  goalTypeIcon(goal.goalType),
                  size: 14,
                  color: scheme.primary,
                ),
              ),
              TaskMetaChip(
                label: goalDirectionLabel(goal.direction),
                tintColor: directionColor,
                leading: Icon(
                  goalDirectionIcon(goal.direction),
                  size: 14,
                  color: directionColor,
                ),
              ),
              if (goal.milestoneCount > 0)
                TaskMetaChip(
                  label:
                      '${goal.milestoneCount} milestone${goal.milestoneCount == 1 ? '' : 's'}',
                  tintColor: goalMilestoneChipColor,
                  leading: Icon(
                    Icons.flag_outlined,
                    size: 14,
                    color: goalMilestoneChipColor,
                  ),
                ),
              if (dateLabel != null)
                TaskMetaChip(
                  label: dateLabel,
                  tintColor: taskTimelineAccentColor,
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: taskTimelineAccentColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TrackerStrengthBar(
            fraction: (progressPercent / 100).clamp(0.0, 1.0),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}
