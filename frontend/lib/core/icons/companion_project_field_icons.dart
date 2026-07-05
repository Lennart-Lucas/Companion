import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Icons for project status form fields (registered in [setupCompanionIcons]).
const IconSet companionProjectFieldIcons = IconSet(
  categories: [
    IconCategory(name: 'Project status', sequence: 4),
  ],
  entries: [
    IconEntry(
      name: 'Project Status Planning',
      data: FontAwesomeIcons.circle,
      category: 'Project status',
      sequence: 0,
      tags: ['status', 'planning', 'circle'],
    ),
    IconEntry(
      name: 'Project Status Active',
      data: FontAwesomeIcons.circlePlay,
      category: 'Project status',
      sequence: 1,
      tags: ['status', 'active', 'circle', 'play'],
    ),
    IconEntry(
      name: 'Project Status On Hold',
      data: FontAwesomeIcons.circlePause,
      category: 'Project status',
      sequence: 2,
      tags: ['status', 'on_hold', 'hold', 'circle', 'pause'],
    ),
    IconEntry(
      name: 'Project Status Completed',
      data: FontAwesomeIcons.circleCheck,
      category: 'Project status',
      sequence: 3,
      tags: ['status', 'completed', 'done', 'circle', 'check'],
    ),
    IconEntry(
      name: 'Project Status Cancelled',
      data: FontAwesomeIcons.circleXmark,
      category: 'Project status',
      sequence: 4,
      tags: ['status', 'cancelled', 'stopped', 'circle', 'x'],
    ),
  ],
);

abstract final class ProjectFieldIconNames {
  static const statusPlanning = 'Project Status Planning';
  static const statusActive = 'Project Status Active';
  static const statusOnHold = 'Project Status On Hold';
  static const statusCompleted = 'Project Status Completed';
  static const statusCancelled = 'Project Status Cancelled';

  static String statusForValue(String value) => switch (value) {
        'planning' => statusPlanning,
        'active' => statusActive,
        'on_hold' => statusOnHold,
        'completed' => statusCompleted,
        'cancelled' => statusCancelled,
        _ => statusPlanning,
      };
}
