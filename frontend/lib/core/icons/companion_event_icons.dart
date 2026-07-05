import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Icons for events (registered in [setupCompanionIcons]).
const IconSet companionEventIcons = IconSet(
  categories: [
    IconCategory(name: 'Events', sequence: 5),
  ],
  entries: [
    IconEntry(
      name: 'Calendar',
      data: FontAwesomeIcons.calendarDays,
      category: 'Events',
      sequence: 0,
      tags: ['event', 'calendar', 'schedule', 'date', 'appointment'],
    ),
  ],
);
