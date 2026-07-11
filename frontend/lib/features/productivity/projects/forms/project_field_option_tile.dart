import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/icons/companion_project_field_icons.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';

/// Colored icon + label row for project status dropdown items.
Widget projectStatusOptionTile(
  AnvilFieldOption<String> option,
  ColorScheme scheme,
) {
  final iconName = ProjectFieldIconNames.statusForValue(option.value);
  final iconData = IconRegistry.instance.getIconData(iconName);
  final iconColor = projectStatusColor(option.value, scheme);

  return Row(
    children: [
      if (iconData != null) ...[
        FaIcon(iconData, size: 22, color: iconColor),
        const SizedBox(width: 10),
      ],
      Expanded(child: Text(option.label)),
    ],
  );
}

Color projectStatusColor(String value, ColorScheme scheme) => switch (value) {
      'planning' => scheme.primary.withValues(alpha: 0.85),
      'active' => companionTrackerBlue,
      'on_hold' => scheme.primary,
      'completed' => companionSuccessColor,
      'cancelled' => scheme.error,
      _ => scheme.onSurface,
    };

List<AnvilFieldOption<String>> projectStatusOptions() => const [
      AnvilFieldOption(value: 'planning', label: 'Planning'),
      AnvilFieldOption(value: 'active', label: 'Active'),
      AnvilFieldOption(value: 'on_hold', label: 'On hold'),
      AnvilFieldOption(value: 'completed', label: 'Completed'),
      AnvilFieldOption(value: 'cancelled', label: 'Cancelled'),
    ];
