import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/services/task_bucket_summary.dart';

/// To Do / Overdue / Unplanned / Completed bucket cards for the current day section.
class TaskBucketRow extends StatelessWidget {
  const TaskBucketRow({
    super.key,
    required this.summary,
    required this.onBucketTap,
  });

  final TaskBucketSummary summary;
  final ValueChanged<TaskBucket> onBucketTap;

  static const _cardGap = 8.0;
  static const _titleGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: CompanionFormStyles.taskRowVerticalGap,
        left: CompanionFormStyles.taskTimelineWidth,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Today',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: _titleGap),
          Row(
            children: [
              for (var i = 0; i < taskBucketDisplayOrder.length; i++) ...[
                if (i > 0) const SizedBox(width: _cardGap),
                Expanded(
                  child: _BucketCard(
                    label: taskBucketLabel(taskBucketDisplayOrder[i]),
                    count: summary.count(taskBucketDisplayOrder[i]),
                    onTap: () => onBucketTap(taskBucketDisplayOrder[i]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = CompanionFormStyles.taskSurfaceTint(
      scheme,
      CompanionFormStyles.taskBucketBackgroundAlpha,
    );

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.85),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
