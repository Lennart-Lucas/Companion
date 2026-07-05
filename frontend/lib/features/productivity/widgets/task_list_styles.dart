import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/forms/task_field_option_tile.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

/// Timeline accent for non-status metadata (e.g. time label).
const Color taskTimelineAccentColor = Color(0xFF42A5F5);

/// Default registry icon names for parent chips (matches list tiles).
abstract final class TaskCategoryChipDefaults {
  static const projectIcon = 'Person Digging';
  static const goalIcon = 'Bullseye';
  static const trackerIcon = 'Chart Line';
  static const taskIcon = 'Check Double';
}

IconData resolveTaskCategoryIconData({
  String? iconName,
  required String defaultIconName,
  required IconData materialFallback,
}) {
  final trimmed = iconName?.trim();
  final resolvedName =
      (trimmed != null && trimmed.isNotEmpty) ? trimmed : defaultIconName;
  return IconRegistry.instance.getIconData(resolvedName) ?? materialFallback;
}

/// Resolves a project/goal icon for [TaskCategoryChip].
Widget taskCategoryChipIcon({
  String? iconName,
  required String defaultIconName,
  required IconData materialFallback,
  required Color color,
  double size = 14,
}) {
  final trimmed = iconName?.trim();
  final resolvedName =
      (trimmed != null && trimmed.isNotEmpty) ? trimmed : defaultIconName;
  final iconData = IconRegistry.instance.getIconData(resolvedName);
  if (iconData != null) {
    return FaIcon(iconData, size: size, color: color);
  }
  return Icon(materialFallback, size: size, color: color);
}

/// Rounded-square icon badge for project/tracker list tiles.
enum TaskTimelineIconBadgeSize { timeline, panel }

class TaskTimelineIconBadge extends StatelessWidget {
  const TaskTimelineIconBadge({
    super.key,
    required this.color,
    required this.defaultIconName,
    required this.materialFallback,
    this.iconName,
    this.size = TaskTimelineIconBadgeSize.panel,
  });

  final Color color;
  final String defaultIconName;
  final IconData materialFallback;
  final String? iconName;
  final TaskTimelineIconBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final isPanel = size == TaskTimelineIconBadgeSize.panel;
    final outerSize = isPanel
        ? CompanionFormStyles.taskPanelIconBadgeSize
        : CompanionFormStyles.taskTimelineNodeOuterSize;
    final innerSize = isPanel
        ? CompanionFormStyles.taskPanelIconBadgeSize
        : CompanionFormStyles.taskTimelineNodeSize;
    final radius = isPanel
        ? CompanionFormStyles.taskPanelIconBadgeRadius
        : CompanionFormStyles.taskTimelineIconBadgeRadius;
    final iconSize = isPanel
        ? CompanionFormStyles.taskPanelIconBadgeIconSize
        : CompanionFormStyles.taskTimelineIconBadgeIconSize;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: SizedBox(
          width: innerSize,
          height: innerSize,
          child: Center(
            child: taskCategoryChipIcon(
              iconName: iconName,
              defaultIconName: defaultIconName,
              materialFallback: materialFallback,
              color: color,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical timeline column with connecting line segments and a status node slot.
class TaskTimelineColumn extends StatelessWidget {
  const TaskTimelineColumn({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.statusNode,
    this.fillHeight = true,
  });

  final bool isFirst;
  final bool isLast;
  final Widget statusNode;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = scheme.primary;
    const lineWidth = CompanionFormStyles.taskTimelineLineWidth;
    const overhang = CompanionFormStyles.taskTimelineLineOverhang;
    const topSegment = CompanionFormStyles.taskTimelineLineTopSegment;
    const nodeOuterSize = CompanionFormStyles.taskTimelineNodeOuterSize;
    const columnWidth = CompanionFormStyles.taskTimelineWidth;
    final lineLeft = (columnWidth - lineWidth) / 2;
    final bottomLineTop = topSegment + nodeOuterSize;

    if (!fillHeight) {
      return SizedBox(
        width: columnWidth,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: topSegment),
                statusNode,
              ],
            ),
            if (!isFirst)
              Positioned(
                top: -overhang,
                left: lineLeft,
                width: lineWidth,
                height: topSegment + overhang,
                child: ColoredBox(color: lineColor),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: columnWidth,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: topSegment),
              statusNode,
            ],
          ),
          if (!isFirst)
            Positioned(
              top: -overhang,
              left: lineLeft,
              width: lineWidth,
              height: topSegment + overhang,
              child: ColoredBox(color: lineColor),
            ),
          if (!isLast)
            Positioned(
              top: bottomLineTop,
              left: lineLeft,
              width: lineWidth,
              bottom: -overhang,
              child: ColoredBox(color: lineColor),
            ),
        ],
      ),
    );
  }
}

Widget timelineCirclePlusIcon({
  required double size,
  required Color color,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        FaIcon(FontAwesomeIcons.circle, size: size, color: color),
        FaIcon(
          FontAwesomeIcons.plus,
          size: size * 0.42,
          color: color,
        ),
      ],
    ),
  );
}

Widget timelineCirclePlayIcon({
  required double size,
  required Color color,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        FaIcon(FontAwesomeIcons.circle, size: size, color: color),
        FaIcon(
          FontAwesomeIcons.play,
          size: size * 0.38,
          color: color,
        ),
      ],
    ),
  );
}

/// Blue pause control for duration tracker timers.
const Color durationTimerPauseColor = Color(0xFF2196F3);

Widget timelineCirclePauseIcon({
  required double size,
  required Color color,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        FaIcon(FontAwesomeIcons.circle, size: size, color: color),
        FaIcon(
          FontAwesomeIcons.pause,
          size: size * 0.38,
          color: color,
        ),
      ],
    ),
  );
}

/// Tappable timeline status node (hollow or filled circle).
class TaskTimelineStatusButton extends StatelessWidget {
  const TaskTimelineStatusButton({
    super.key,
    required this.status,
    required this.onPressed,
    this.enabled = true,
  });

  final String status;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = taskStatusColor(status, scheme);
    final size = CompanionFormStyles.taskTimelineNodeSize;

    return IconButton(
      tooltip: 'Cycle status',
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: statusColor,
        disabledForegroundColor: statusColor.withValues(alpha: 0.38),
      ),
      constraints: BoxConstraints.tightFor(width: size + 8, height: size + 8),
      icon: taskStatusIcon(
        status: status,
        scheme: scheme,
        size: CompanionFormStyles.taskTimelineIconSize,
      ),
    );
  }
}

/// Circle plus control at the bottom of the task timeline.
class TaskTimelineAddButton extends StatelessWidget {
  const TaskTimelineAddButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = CompanionFormStyles.taskTimelineNodeSize;

    return IconButton(
      tooltip: 'Add task',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
      ),
      constraints: BoxConstraints.tightFor(width: size + 8, height: size + 8),
      icon: _taskTimelineAddIcon(
        size: CompanionFormStyles.taskTimelineIconSize,
        color: scheme.primary,
      ),
    );
  }
}

Widget _taskTimelineAddIcon({
  required double size,
  required Color color,
}) {
  return timelineCirclePlusIcon(size: size, color: color);
}

/// Section header for a date group in the task list.
class TaskListDateHeader extends StatelessWidget {
  const TaskListDateHeader({
    super.key,
    required this.day,
    required this.listToday,
    this.headerKey,
  });

  /// Local calendar day at midnight, or null for the unscheduled group.
  final DateTime? day;
  final DateTime listToday;
  final Key? headerKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = day == null
        ? 'Unscheduled'
        : formatTaskListDateHeader(day!, now: listToday);

    return Padding(
      key: headerKey,
      padding: const EdgeInsets.only(
        top: CompanionFormStyles.sectionHeaderMarginTop,
        bottom: CompanionFormStyles.sectionHeaderMarginBottom,
        left: CompanionFormStyles.taskTimelineWidth,
      ),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Small loader shown while extending the list horizon.
class TaskListLoadingTile extends StatelessWidget {
  const TaskListLoadingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Timeline row with a plus button to create a new task.
class TaskListAddTile extends StatelessWidget {
  const TaskListAddTile({
    super.key,
    required this.onPressed,
    this.hasTasksAbove = true,
  });

  final VoidCallback onPressed;
  final bool hasTasksAbove;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskTimelineColumn(
            isFirst: !hasTasksAbove,
            isLast: true,
            fillHeight: false,
            statusNode: TaskTimelineAddButton(onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}

/// Semi-transparent rounded panel for task row content.
class TaskRowPanel extends StatelessWidget {
  const TaskRowPanel({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(
          alpha: CompanionFormStyles.taskRowBackgroundAlpha,
        ),
        borderRadius: BorderRadius.circular(
          CompanionFormStyles.taskRowPanelRadius,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CompanionFormStyles.taskRowPanelPadding),
        child: child,
      ),
    );
  }
}

/// Tinted metadata pill for linked project or goal (matches [TaskMetaChip]).
class TaskCategoryChip extends StatelessWidget {
  const TaskCategoryChip({
    super.key,
    required this.label,
    required this.tintColor,
    this.leading,
  });

  final String label;
  final Color tintColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return TaskMetaChip(
      label: label,
      tintColor: tintColor,
      leading: leading,
    );
  }
}

/// Neutral metadata pill (subtask progress).
class TaskMetaChip extends StatelessWidget {
  const TaskMetaChip({
    super.key,
    required this.label,
    this.leading,
    this.tintColor,
    this.neutral = false,
  });

  final String label;
  final Widget? leading;
  final Color? tintColor;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = tintColor ?? scheme.onSurface;
    final background = neutral
        ? scheme.onSurface.withValues(alpha: 0.12)
        : accent.withValues(alpha: 0.12);
    final borderColor = neutral
        ? scheme.onSurface.withValues(alpha: 0.2)
        : accent.withValues(alpha: 0.35);
    final foreground =
        neutral ? scheme.onSurface.withValues(alpha: 0.85) : accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Subtask row with pending/completed status icon (matches timeline node).
class TaskTimelineSubtaskRow extends StatelessWidget {
  const TaskTimelineSubtaskRow({
    super.key,
    required this.title,
    required this.completed,
    this.onTap,
  });

  final String title;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = completed ? 'completed' : 'pending';
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Opacity(
                opacity: enabled ? 1 : 0.38,
                child: taskStatusIcon(
                  status: status,
                  scheme: scheme,
                  size: CompanionFormStyles.taskTimelineIconSize,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration:
                        completed ? TextDecoration.lineThrough : null,
                    color: completed
                        ? scheme.onSurface.withValues(alpha: 0.55)
                        : enabled
                            ? null
                            : scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
