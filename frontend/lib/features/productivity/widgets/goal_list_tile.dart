import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/widgets/goal_display.dart';

/// List row for a [Goal] with icon, type, target, and direction.
class GoalListTile extends StatelessWidget {
  const GoalListTile({
    super.key,
    required this.goal,
    this.onTap,
  });

  final Goal goal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconName = goal.icon?.trim();
    final leadingIconData = (iconName != null && iconName.isNotEmpty)
        ? IconRegistry.instance.getIconData(iconName)
        : IconRegistry.instance.getIconData('Bullseye');
    final leadingColor =
        parseGoalColor(goal.color, scheme.primary) ?? scheme.primary;

    return ListTile(
      onTap: onTap,
      leading: leadingIconData != null
          ? FaIcon(leadingIconData, size: 22, color: leadingColor)
          : Icon(Icons.flag_outlined, size: 22, color: leadingColor),
      title: Text(goal.name),
      subtitle: Text(goalSubtitle(goal)),
      trailing: Icon(
        goal.direction == GoalDirection.increasing
            ? Icons.trending_up
            : Icons.trending_down,
        size: 20,
        color: goal.direction == GoalDirection.increasing
            ? companionSuccessColor
            : scheme.error,
      ),
    );
  }
}
