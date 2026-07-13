import 'package:flutter/material.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_card_carousel.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_check_ins.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_goal_card.dart';

class WeeklySummaryGoalsSection extends StatelessWidget {
  const WeeklySummaryGoalsSection({
    super.key,
    required this.goals,
    required this.weekStart,
    required this.listToday,
    required this.checkIns,
  });

  final List<WeeklyGoalSummary> goals;
  final DateTime weekStart;
  final DateTime listToday;
  final WeeklySummaryCheckIns checkIns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCurrentWeek = taskListWeekIsCurrent(weekStart, now: listToday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Goals',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (goals.isEmpty)
          Text(
            'No goal activity this week',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          WeeklySummaryCardCarousel(
            itemCount: goals.length,
            cardHeight: 220,
            itemBuilder: (context, index) {
              final item = goals[index];
              final showLog = isCurrentWeek && item.todayCheckIn != null;
              return WeeklySummaryGoalCard(
                summary: item,
                showLogButton: showLog,
                onTap: () => CompanionNavigation.openGoalDetail(
                  context,
                  goalId: item.goal.id,
                  goal: item.goal,
                ),
                onLogPressed: showLog
                    ? () => checkIns.openGoalCheckIn(
                        goal: item.goal,
                        checkIn: item.todayCheckIn,
                        checkInAt: listToday,
                      )
                    : null,
              );
            },
          ),
      ],
    );
  }
}
