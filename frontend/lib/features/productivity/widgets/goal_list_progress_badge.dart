import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/widgets/goal_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

/// Circular progress badge for goal list tiles.
class GoalListProgressBadge extends StatelessWidget {
  const GoalListProgressBadge({
    super.key,
    required this.fraction,
    required this.goalColor,
    this.iconName,
    this.compact = false,
  });

  static const _ringSize = 64.0;
  static const _compactRingSize = 52.0;
  static const _iconSize = 22.0;
  static const _compactIconSize = 18.0;
  static const _trackSweep = 0.75;

  final double fraction;
  final Color goalColor;
  final String? iconName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ringSize = compact ? _compactRingSize : _ringSize;
    final iconSize = compact ? _compactIconSize : _iconSize;
    final percent = (fraction.clamp(0.0, 1.0) * 100).round();
    final percentStyle = (compact
            ? theme.textTheme.labelSmall
            : theme.textTheme.labelMedium)
        ?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface.withValues(alpha: 0.92),
      height: 1,
    );

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TrackerProgressRing(
            fraction: fraction,
            color: goalProgressColor(percent.toDouble()),
            size: ringSize,
            strokeWidth: compact ? 4.0 : 4.5,
            trackSweep: _trackSweep,
            center: Icon(
              resolveTaskCategoryIconData(
                iconName: iconName,
                defaultIconName: TaskCategoryChipDefaults.goalIcon,
                materialFallback: Icons.flag_outlined,
              ),
              size: iconSize,
              color: goalColor,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: compact ? 1 : 2,
            child: Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                style: percentStyle,
                children: [
                  TextSpan(text: '$percent'),
                  const TextSpan(text: '%'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
