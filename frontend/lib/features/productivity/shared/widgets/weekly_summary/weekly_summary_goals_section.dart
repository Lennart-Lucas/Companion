import 'package:flutter/material.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/core/routing/companion_routes.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_card_carousel.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_check_ins.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_goal_card.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_section.dart';
import 'package:go_router/go_router.dart';

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

    return WeeklySummarySection(
      title: 'Goals',
      onViewAll: () => context.go(CompanionRoutes.productivityGoals),
      child: goals.isEmpty
          ? Text(
              'No goal activity this week',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : WeeklySummaryCardCarousel(
              itemCount: goals.length,
              cardHeight: 240,
              itemBuilder: (context, index) {
                final item = goals[index];
                final showLog = isCurrentWeek && item.todayCheckIn != null;
                return WeeklySummaryGoalCard(
                  summary: item,
                  listToday: listToday,
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
    );
  }
}
