import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class WeeklySummaryTasksSection extends StatelessWidget {
  const WeeklySummaryTasksSection({super.key, required this.summary});

  final WeeklyTaskSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tasks',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(
                label: 'Completed',
                value: '${summary.completed}',
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Planned',
                value: '${summary.planned}',
                color: scheme.onSurface,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Overdue',
                value: '${summary.overdue}',
                color: scheme.error,
              ),
            ],
          ),
          if (summary.completedEntries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Completed this week',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in summary.completedEntries.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(entry.task.name, style: theme.textTheme.bodyMedium),
              ),
            if (summary.completedEntries.length > 8)
              Text(
                '+ ${summary.completedEntries.length - 8} more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: CompanionFormStyles.taskListPanelBackground(theme.colorScheme),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
