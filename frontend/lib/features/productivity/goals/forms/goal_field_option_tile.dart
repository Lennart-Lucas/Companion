import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';


List<AnvilFieldOption<String>> goalTypeOptions() => const [
      AnvilFieldOption(value: GoalType.count, label: 'Count'),
      AnvilFieldOption(value: GoalType.task, label: 'Task'),
      AnvilFieldOption(value: GoalType.pulse, label: 'Pulse'),
    ];

List<AnvilFieldOption<String>> goalDirectionOptions() => const [
      AnvilFieldOption(
        value: GoalDirection.increasing,
        label: 'Increasing (do more)',
      ),
      AnvilFieldOption(
        value: GoalDirection.decreasing,
        label: 'Decreasing (do less)',
      ),
    ];

Widget goalTypeOptionTile(
  AnvilFieldOption<String> option,
  ColorScheme scheme,
) {
  return Row(
    children: [
      Icon(
        _goalTypeIcon(option.value),
        size: 22,
        color: scheme.primary,
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(option.label)),
    ],
  );
}

Widget goalDirectionOptionTile(
  AnvilFieldOption<String> option,
  ColorScheme scheme,
) {
  return Row(
    children: [
      Icon(
        option.value == GoalDirection.increasing
            ? Icons.trending_up
            : Icons.trending_down,
        size: 22,
        color: option.value == GoalDirection.increasing
            ? companionSuccessColor
            : scheme.error,
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(option.label)),
    ],
  );
}

IconData _goalTypeIcon(String value) => switch (value) {
      GoalType.count => Icons.numbers,
      GoalType.task => Icons.check_circle_outline,
      GoalType.pulse => Icons.favorite_outline,
      _ => Icons.flag_outlined,
    };
