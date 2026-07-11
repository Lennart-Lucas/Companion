import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/goals/services/goal_stats.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_stat_items.dart';

class GoalSidebarStatsList extends StatelessWidget {
  const GoalSidebarStatsList({
    super.key,
    required this.goal,
    required this.stats,
  });

  final Goal goal;
  final GoalStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = buildGoalSidebarStatItems(goal: goal, stats: stats);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.55),
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface.withValues(alpha: 0.92),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outline.withValues(alpha: 0.2),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  items[i].label,
                  style: labelStyle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                items[i].value,
                textAlign: TextAlign.right,
                style: valueStyle?.copyWith(
                  color: items[i].valueColor ?? valueStyle.color,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
