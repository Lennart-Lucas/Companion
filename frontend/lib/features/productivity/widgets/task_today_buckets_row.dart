import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/services/task_today_buckets.dart';

/// Horizontal bucket summary cards shown under the Today header.
class TaskTodayBucketsRow extends StatelessWidget {
  const TaskTodayBucketsRow({
    super.key,
    required this.counts,
    required this.onBucketTap,
  });

  static const rowHeight = 88.0;

  final TaskTodayBucketCounts counts;
  final ValueChanged<TaskTodayBucket> onBucketTap;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    final buckets = TaskTodayBucket.values;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: CompanionFormStyles.sectionHeaderMarginBottom,
        left: CompanionFormStyles.taskTimelineWidth,
      ),
      child: Row(
        children: [
          for (var i = 0; i < buckets.length; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(
              child: _BucketCard(
                label: buckets[i].label,
                count: counts.countFor(buckets[i]),
                onTap: () => onBucketTap(buckets[i]),
              ),
            ),
          ],
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
    final background = CompanionFormStyles.taskListPanelBackground(scheme);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: TaskTodayBucketsRow.rowHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
