import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/icons/companion_task_field_icons.dart';

/// Renders a task status/priority field icon at [size] and [color].
///
/// [TaskFieldIconNames.priorityUrgent] uses a stacked outline circle plus
/// exclamation because Font Awesome Free has no regular `circle-exclamation`
/// glyph (only the solid, filled variant).
Widget companionTaskFieldIcon({
  IconData? iconData,
  String? iconName,
  required double size,
  required Color color,
}) {
  if (iconName == TaskFieldIconNames.priorityUrgent) {
    return _outlineCircleExclamation(size: size, color: color);
  }
  if (iconData == null) {
    return const SizedBox.shrink();
  }
  return FaIcon(iconData, size: size, color: color);
}

Widget _outlineCircleExclamation({
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
          FontAwesomeIcons.exclamation,
          size: size * 0.42,
          color: color,
        ),
      ],
    ),
  );
}
