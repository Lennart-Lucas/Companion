import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/goals/services/goal_stats.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_value_over_time_section.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_month_logged_calendar.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_related_records_section.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_stat_items.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_stats_highlight_row.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class GoalStatsSection extends StatelessWidget {
  const GoalStatsSection({
    super.key,
    required this.goal,
    required this.stats,
    required this.checkIns,
    required this.listToday,
    required this.displayedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onGoToCurrentMonth,
    this.onDaySelected,
    this.showHighlightRow = true,
    this.showStatCards = true,
  });

  final Goal goal;
  final GoalStats stats;
  final List<GoalCheckIn> checkIns;
  final DateTime listToday;
  final DateTime displayedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onGoToCurrentMonth;
  final ValueChanged<DateTime>? onDaySelected;
  final bool showHighlightRow;
  final bool showStatCards;

  @override
  Widget build(BuildContext context) {
    final cards = buildGoalStatItems(goal: goal, stats: stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHighlightRow) ...[
          const SizedBox(height: 16),
          GoalStatsHighlightRow(stats: stats),
          const SizedBox(height: 16),
        ],
        if (showStatCards) ...[
          Wrap(
            spacing: CompanionFormStyles.taskListChipGap,
            runSpacing: CompanionFormStyles.taskListChipGap,
            children: [
              for (final card in cards)
                GoalStatCard(
                  label: card.label,
                  value: card.value,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        GoalValueOverTimeSection(
          goal: goal,
          stats: stats,
          checkIns: checkIns,
          listToday: listToday,
        ),
        const SizedBox(height: 16),
        GoalMonthLoggedCalendar(
          displayedMonth: displayedMonth,
          listToday: listToday,
          dayOutcomes: stats.dayOutcomes,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
          onGoToCurrentMonth: onGoToCurrentMonth,
          onDaySelected: onDaySelected,
          goalStartDate: goal.startDate,
          goalEndDate: goal.endDate,
        ),
        const SizedBox(height: 16),
        GoalRelatedRecordsSection(
          goal: goal,
          listToday: listToday,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class GoalStatCard extends StatelessWidget {
  const GoalStatCard({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 156,
      child: TrackerRowPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
