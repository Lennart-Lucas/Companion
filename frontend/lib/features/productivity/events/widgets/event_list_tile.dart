import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/features/productivity/events/models/event.dart';

import 'package:frontend/features/productivity/events/widgets/event_display.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';

/// List row for an [Event] with icon and date range.
class EventListTile extends StatelessWidget {
  const EventListTile({
    super.key,
    required this.event,
    this.onTap,
  });

  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconName = event.icon?.trim();
    final leadingIconData = (iconName != null && iconName.isNotEmpty)
        ? IconRegistry.instance.getIconData(iconName)
        : IconRegistry.instance.getIconData('Calendar');
    final leadingColor =
        parseProjectColor(event.color, scheme.primary) ?? scheme.primary;
    final subtitle = eventSubtitle(event);

    return ListTile(
      onTap: onTap,
      leading: leadingIconData != null
          ? FaIcon(leadingIconData, size: 22, color: leadingColor)
          : Icon(Icons.calendar_today_outlined, size: 22, color: leadingColor),
      title: Text(event.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty) Text(subtitle),
          if (event.isRecurring)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.repeat,
                    size: 14,
                    color: scheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Repeating',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.secondary,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: Icon(
        Icons.calendar_today_outlined,
        size: 20,
        color: scheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}
