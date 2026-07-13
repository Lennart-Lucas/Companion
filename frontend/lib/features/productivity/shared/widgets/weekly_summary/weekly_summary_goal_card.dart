import 'package:flutter/material.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_log_button.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_display.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_list_progress_badge.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class WeeklySummaryGoalCard extends StatelessWidget {
  const WeeklySummaryGoalCard({
    super.key,
    required this.summary,
    required this.showLogButton,
    this.onTap,
    this.onLogPressed,
  });

  final WeeklyGoalSummary summary;
  final bool showLogButton;
  final VoidCallback? onTap;
  final VoidCallback? onLogPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = summary.goal;
    final goalColor =
        parseGoalColor(goal.color, scheme.primary) ?? scheme.primary;
    final progressFraction = (summary.progressPercent / 100).clamp(0.0, 1.0);
    final consistencyPercent = (summary.consistency * 100).round();
    final lastCheckInLabel = _formatLastCheckIn(summary.lastCheckInAt);

    return TrackerRowPanel(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GoalListProgressBadge(
                    fraction: progressFraction,
                    goalColor: goalColor,
                    iconName: goal.icon,
                    compact: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goal.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TrackerStrengthBar(
                fraction: progressFraction,
                label: 'Progress',
                animate: false,
              ),
              const SizedBox(height: 8),
              Text(
                '$consistencyPercent% consistency · $lastCheckInLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              if (showLogButton) ...[
                const SizedBox(height: 8),
                WeeklySummaryLogButton(
                  label: summary.loggedToday
                      ? 'Logged today ✓'
                      : 'Log check-in',
                  enabled: !summary.loggedToday && onLogPressed != null,
                  filled: !summary.loggedToday,
                  color: summary.loggedToday
                      ? trackerStrengthHighColor
                      : goalColor,
                  onPressed: summary.loggedToday ? null : onLogPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastCheckIn(DateTime? at) {
    if (at == null) return 'No check-ins yet';
    final local = at.toLocal();
    final now = DateTime.now();
    final today = normalizeTaskListCalendarDay(now);
    final day = normalizeTaskListCalendarDay(local);
    if (day == today) return 'Last check-in today';
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == yesterday) return 'Last check-in yesterday';
    return 'Last check-in ${local.day}/${local.month}';
  }
}
