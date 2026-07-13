import 'package:flutter/material.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/shared/services/weekly_summary_timeline.dart';

/// App bar for the weekly summary overview dashboard.
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
    final rangeLabel = formatWeekRangeLabelHeader(weekStart);
    final isCurrentWeek = taskListWeekIsCurrent(weekStart, now: listToday);
    final nextWeekSunday =
        taskListWeekEnd(weekStart.add(const Duration(days: 7)));
    final canGoForward = shouldShowWeeklySummary(nextWeekSunday, listToday);

    return AppBar(
      title: Row(
        children: [
          Text(
            'Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _WeekDatePill(
            rangeLabel: rangeLabel,
            onPreviousWeek: onPreviousWeek,
            onNextWeek: canGoForward ? onNextWeek : null,
          ),
        ],
      ),
      backgroundColor: scheme.surface.withValues(alpha: 0.85),
      actions: [
        TextButton(
          onPressed: isCurrentWeek ? null : onGoToCurrentWeek,
          child: const Text('Today'),
        ),
      ],
    );
  }
}

class _WeekDatePill extends StatelessWidget {
  const _WeekDatePill({
    required this.rangeLabel,
    required this.onPreviousWeek,
    this.onNextWeek,
  });

  final String rangeLabel;
  final VoidCallback onPreviousWeek;
  final VoidCallback? onNextWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(
          CompanionFormStyles.taskRowPanelRadius,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous week',
            onPressed: onPreviousWeek,
            icon: const Icon(Icons.chevron_left, size: 20),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Text(
            rangeLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            tooltip: 'Next week',
            onPressed: onNextWeek,
            icon: const Icon(Icons.chevron_right, size: 20),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
