import 'package:flutter/material.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/features/productivity/tasks/services/task_today_buckets.dart';

/// Horizontal bucket summary cards shown under the Today header.
class TaskTodayBucketsRow extends StatelessWidget {
  const TaskTodayBucketsRow({
    super.key,
    required this.counts,
    required this.onBucketTap,
    this.compact = false,
  });

  static const rowHeight = 88.0;

  final TaskTodayBucketCounts counts;
  final ValueChanged<TaskTodayBucket> onBucketTap;

  /// When true, buckets span the full viewport width with no side insets.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buckets = TaskTodayBucket.values;
    final gap = compact ? 0.0 : 10.0;

    final row = Row(
      children: [
        for (var i = 0; i < buckets.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: _BucketCard(
              bucket: buckets[i],
              label: buckets[i].label,
              count: counts.countFor(buckets[i]),
              onTap: () => onBucketTap(buckets[i]),
              borderRadius: _borderRadiusForIndex(i, buckets.length),
            ),
          ),
        ],
      ],
    );

    if (!compact) {
      return Padding(
        padding: const EdgeInsets.only(
          bottom: CompanionFormStyles.sectionHeaderMarginBottom,
          left: CompanionFormStyles.taskTimelineWidth,
        ),
        child: row,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bleedLeft = CompanionLayout.compactBucketBleedLeft;
        final bleedRight = CompanionLayout.compactBucketBleedRight;
        final fullWidth = constraints.maxWidth + bleedLeft + bleedRight;

        return Padding(
          padding: const EdgeInsets.only(
            bottom: CompanionFormStyles.sectionHeaderMarginBottom,
          ),
          child: Transform.translate(
            offset: Offset(-bleedLeft, 0),
            child: SizedBox(
              width: fullWidth,
              child: row,
            ),
          ),
        );
      },
    );
  }

  BorderRadius _borderRadiusForIndex(int index, int count) {
    if (!compact) {
      return BorderRadius.circular(10);
    }
    const radius = Radius.circular(10);
    if (index == 0) {
      return const BorderRadius.only(
        topRight: radius,
        bottomRight: radius,
      );
    }
    if (index == count - 1) {
      return const BorderRadius.only(
        topLeft: radius,
        bottomLeft: radius,
      );
    }
    return BorderRadius.zero;
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.bucket,
    required this.label,
    required this.count,
    required this.onTap,
    required this.borderRadius,
  });

  final TaskTodayBucket bucket;
  final String label;
  final int count;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  static ({Color background, Color countColor, Color labelColor}) _bucketStyle(
    TaskTodayBucket bucket,
    ColorScheme scheme,
  ) {
    final base = CompanionFormStyles.taskListPanelBackground(scheme);
    return switch (bucket) {
      TaskTodayBucket.overdue => (
          background: Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.12),
            base,
          ),
          countColor: scheme.primary,
          labelColor: scheme.primary,
        ),
      TaskTodayBucket.completed => (
          background: Color.alphaBlend(
            companionSuccessColor.withValues(alpha: 0.12),
            base,
          ),
          countColor: companionSuccessColor,
          labelColor: companionSuccessColor,
        ),
      _ => (
          background: base,
          countColor: scheme.onSurface,
          labelColor: scheme.onSurfaceVariant,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = _bucketStyle(bucket, scheme);

    return Material(
      color: style.background,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: SizedBox(
          height: TaskTodayBucketsRow.rowHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: style.countColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: style.labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
