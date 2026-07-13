import 'package:flutter/material.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';
import 'package:frontend/features/productivity/shared/services/weekly_summary_timeline.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';

/// App bar for the weekly summary overview, styled like entity detail pages.
class WeeklySummaryHeader extends StatelessWidget implements PreferredSizeWidget {
  const WeeklySummaryHeader({
    super.key,
    required this.weekStart,
    required this.listToday,
    required this.onPreviousWeek,
    required this.onNextWeek,
    this.onGoToCurrentWeek,
  });

  final DateTime weekStart;
  final DateTime listToday;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback? onGoToCurrentWeek;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rangeLabel = formatWeekRangeLabel(weekStart);
    final isCurrentWeek = taskListWeekIsCurrent(weekStart, now: listToday);
    final nextWeekSunday =
        taskListWeekEnd(weekStart.add(const Duration(days: 7)));
    final canGoForward = shouldShowWeeklySummary(nextWeekSunday, listToday);

    return AppBar(
      title: Row(
        children: [
          TaskTimelineIconBadge(
            color: scheme.primary,
            defaultIconName: 'Chart Pie',
            materialFallback: Icons.summarize_outlined,
          ),
          const SizedBox(width: CompanionFormStyles.taskPanelIconBadgeGap),
          Expanded(
            child: Text(
              rangeLabel,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: scheme.surface.withValues(alpha: 0.85),
      actions: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: onPreviousWeek,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: canGoForward ? onNextWeek : null,
          icon: const Icon(Icons.chevron_right),
        ),
        if (!isCurrentWeek && onGoToCurrentWeek != null)
          TextButton(
            onPressed: onGoToCurrentWeek,
            child: const Text('Today'),
          ),
      ],
    );
  }
}
