import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

List<AnvilFieldOption<String>> trackerCheckInTypeOptions() => const [
      AnvilFieldOption(value: TrackerCheckInType.task, label: 'Task (yes/no)'),
      AnvilFieldOption(value: TrackerCheckInType.count, label: 'Count'),
      AnvilFieldOption(value: TrackerCheckInType.duration, label: 'Duration'),
    ];

List<AnvilFieldOption<String>> trackerHabitDirectionOptions() => const [
      AnvilFieldOption(
        value: TrackerHabitDirection.build,
        label: 'Build (do more)',
      ),
      AnvilFieldOption(
        value: TrackerHabitDirection.quit,
        label: 'Quit (do less)',
      ),
    ];

Widget trackerCheckInTypeOptionTile(
  AnvilFieldOption<String> option,
  ColorScheme scheme,
) {
  return Row(
    children: [
      Icon(
        trackerCheckInTypeIcon(option.value),
        size: 22,
        color: scheme.primary,
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(option.label)),
    ],
  );
}

Widget trackerHabitDirectionOptionTile(
  AnvilFieldOption<String> option,
  ColorScheme scheme,
) {
  return Row(
    children: [
      Icon(
        trackerHabitDirectionIcon(option.value),
        size: 22,
        color: trackerHabitDirectionColor(option.value, scheme),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(option.label)),
    ],
  );
}
