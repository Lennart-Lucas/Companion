import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_log_button.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_tracker_week_strip.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_progress_badge.dart';

class WeeklySummaryTrackerCard extends StatelessWidget {
  const WeeklySummaryTrackerCard({
    super.key,
    required this.summary,
    required this.weekStart,
    required this.listToday,
    required this.showLogButton,
    this.onTap,
    this.onLogPressed,
  });

  final WeeklyTrackerSummary summary;
  final DateTime weekStart;
  final DateTime listToday;
  final bool showLogButton;
  final VoidCallback? onTap;
  final VoidCallback? onLogPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tracker = summary.tracker;
    final trackerColor =
        parseProjectColor(tracker.color, scheme.primary) ??
        trackerHabitBuildColor;
    final weekPercent = (summary.thisWeekPercent * 100).round();

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
                  TrackerListProgressBadge(
                    fraction: summary.thisWeekPercent,
                    trackerColor: trackerColor,
                    iconName: tracker.icon,
                    compact: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tracker.name,
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
              WeeklySummaryTrackerWeekStrip(
                weekStart: weekStart,
                listToday: listToday,
                dayOutcomes: summary.dayOutcomes,
              ),
              const SizedBox(height: 8),
              Text(
                '${summary.currentStreak} day streak · $weekPercent% this week',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (showLogButton) ...[
                const SizedBox(height: 8),
                WeeklySummaryLogButton(
                  label: summary.loggedToday ? 'Logged today ✓' : 'Log today',
                  enabled: !summary.loggedToday && onLogPressed != null,
                  filled: !summary.loggedToday,
                  color: summary.loggedToday
                      ? trackerStrengthHighColor
                      : trackerColor,
                  onPressed: summary.loggedToday ? null : onLogPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
