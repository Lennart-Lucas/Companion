import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/projects/widgets/project_list_progress_badge.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class WeeklySummaryProjectCard extends StatelessWidget {
  const WeeklySummaryProjectCard({
    super.key,
    required this.summary,
    this.onTap,
    this.onTaskTap,
  });

  final WeeklyProjectSummary summary;
  final VoidCallback? onTap;
  final void Function(TaskListEntry entry)? onTaskTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final project = summary.project;
    final projectColor =
        parseProjectColor(project.color, scheme.primary) ?? scheme.primary;
    final progress = summary.progressFraction;

    return TrackerRowPanel(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          CompanionFormStyles.taskRowPanelRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProjectListProgressBadge(
                  fraction: progress,
                  projectColor: projectColor,
                  iconName: project.icon,
                  compact: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    project.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${summary.tasksCompleted}/${summary.tasksTotal} this week',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
                color: projectColor,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: summary.taskEntries.isEmpty
                  ? Text(
                      'No tasks this week',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: summary.taskEntries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final entry = summary.taskEntries[index];
                        return _TaskRow(
                          entry: entry,
                          onTap: onTaskTap == null
                              ? null
                              : () => onTaskTap!(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.entry, this.onTap});

  final TaskListEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final completed = entry.status == 'completed';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: completed
              ? trackerStrengthHighColor.withValues(alpha: 0.15)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              completed ? Icons.check_circle : Icons.crop_square,
              size: 18,
              color: completed
                  ? trackerStrengthHighColor
                  : scheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.task.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: completed ? TextDecoration.lineThrough : null,
                  color: completed
                      ? scheme.onSurface.withValues(alpha: 0.55)
                      : scheme.onSurface.withValues(alpha: 0.92),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
