import 'package:anvil_foundry/anvil_foundry.dart';

import 'package:flutter/material.dart';

import 'package:frontend/core/icons/companion_task_field_icon.dart';
import 'package:frontend/core/icons/companion_task_field_icons.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';



/// Colored icon + label row for task priority dropdown items.

Widget taskPriorityOptionTile(

  AnvilFieldOption<String> option,

  Color iconColor,

) {

  return _optionRow(

    option: option,

    iconColor: iconColor,

    iconName: TaskFieldIconNames.priorityForValue(option.value),

  );

}



/// Status dropdown row — circle-style Font Awesome icons, no extra badge.

Widget taskStatusOptionTile(

  AnvilFieldOption<String> option,

  ColorScheme scheme,

) {

  return Row(

    children: [

      taskStatusIcon(status: option.value, scheme: scheme),

      const SizedBox(width: 10),

      Expanded(child: Text(option.label)),

    ],

  );

}



/// Status icon + color — shared by task form dropdown and task list timeline.

Widget taskStatusIcon({

  required String status,

  required ColorScheme scheme,

  double size = 22,

}) {

  final iconName = TaskFieldIconNames.statusForValue(status);

  return companionTaskFieldIcon(

    iconData: IconRegistry.instance.getIconData(iconName),

    iconName: iconName,

    size: size,

    color: taskStatusColor(status, scheme),

  );

}



Widget taskPriorityIcon({

  required String priority,

  required ColorScheme scheme,

  double size = 22,

}) {

  final iconName = TaskFieldIconNames.priorityForValue(priority);

  final color = taskPriorityColor(priority, scheme);

  return companionTaskFieldIcon(

    iconData: IconRegistry.instance.getIconData(iconName),

    iconName: iconName,

    size: size,

    color: color,

  );

}



Widget _optionRow({

  required AnvilFieldOption<String> option,

  required Color iconColor,

  String? iconName,

}) {

  final resolvedName = iconName ?? _iconNameForOption(option);

  final iconData = option.icon ??

      (resolvedName != null

          ? IconRegistry.instance.getIconData(resolvedName)

          : null);



  return Row(

    children: [

      if (iconData != null || resolvedName != null) ...[

        companionTaskFieldIcon(

          iconData: iconData,

          iconName: resolvedName,

          size: 22,

          color: iconColor,

        ),

        const SizedBox(width: 10),

      ],

      Expanded(child: Text(option.label)),

    ],

  );

}



String? _iconNameForOption(AnvilFieldOption<String> option) {

  return switch (option.value) {

    'pending' || 'in_progress' || 'completed' || 'cancelled' =>

      TaskFieldIconNames.statusForValue(option.value),

    'low' || 'medium' || 'high' || 'urgent' =>

      TaskFieldIconNames.priorityForValue(option.value),

    _ => null,

  };

}



/// Matches [AnvilBackgroundIcon] default watermark emphasis.

Color taskStatusWatermarkColor(ColorScheme scheme) =>

    scheme.primary.withValues(alpha: 0.85);



/// Semantic accent colors (readable on Hub dark surfaces).
const Color _taskSemanticGreen = companionSuccessColor;
const Color _taskSemanticBlue = companionTrackerBlue;

Color taskStatusColor(String value, ColorScheme scheme) => switch (value) {

      'pending' => scheme.primary,

      'in_progress' => _taskSemanticBlue,

      'completed' => _taskSemanticGreen,

      'cancelled' => scheme.error,

      _ => scheme.onSurface,

    };



Color taskPriorityColor(String value, ColorScheme scheme) => switch (value) {

      'low' => _taskSemanticGreen,

      'medium' => _taskSemanticBlue,

      'high' => scheme.primary,

      'urgent' => scheme.error,

      _ => scheme.onSurface.withValues(alpha: 0.5),

    };



List<AnvilFieldOption<String>> taskStatusOptions() => const [

      AnvilFieldOption(value: 'pending', label: 'Pending'),

      AnvilFieldOption(value: 'in_progress', label: 'In progress'),

      AnvilFieldOption(value: 'completed', label: 'Completed'),

      AnvilFieldOption(value: 'cancelled', label: 'Cancelled'),

    ];



List<AnvilFieldOption<String>> taskPriorityOptions() => const [

      AnvilFieldOption(value: 'low', label: 'Low'),

      AnvilFieldOption(value: 'medium', label: 'Medium'),

      AnvilFieldOption(value: 'high', label: 'High'),

      AnvilFieldOption(value: 'urgent', label: 'Urgent'),

    ];

