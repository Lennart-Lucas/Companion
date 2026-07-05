import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Icons for task status and priority form fields (registered in [setupCompanionIcons]).
///
/// Priority uses [IconDataRegular] circle glyphs where available in the free set
/// ([circleDown], [circle], [circleUp]). Urgent is drawn via
/// [companionTaskFieldIcon] (outline ring + exclamation) because Free has no
/// regular `circle-exclamation` glyph.
const IconSet companionTaskFieldIcons = IconSet(
  categories: [
    IconCategory(name: 'Task status', sequence: 2),
    IconCategory(name: 'Task priority', sequence: 3),
  ],
  entries: [
    IconEntry(
      name: 'Status Pending',
      data: FontAwesomeIcons.circle,
      category: 'Task status',
      sequence: 0,
      tags: ['status', 'pending', 'waiting', 'empty', 'circle'],
    ),
    IconEntry(
      name: 'Status In Progress',
      data: FontAwesomeIcons.circlePlay,
      category: 'Task status',
      sequence: 1,
      tags: ['status', 'progress', 'active', 'circle', 'play'],
    ),
    IconEntry(
      name: 'Status Completed',
      data: FontAwesomeIcons.circleCheck,
      category: 'Task status',
      sequence: 2,
      tags: ['status', 'completed', 'done', 'check', 'circle'],
    ),
    IconEntry(
      name: 'Status Cancelled',
      data: FontAwesomeIcons.circleXmark,
      category: 'Task status',
      sequence: 3,
      tags: ['status', 'cancelled', 'stopped', 'circle', 'x'],
    ),
    IconEntry(
      name: 'Priority Low',
      data: FontAwesomeIcons.circleDown,
      category: 'Task priority',
      sequence: 0,
      tags: ['priority', 'low', 'down', 'circle'],
    ),
    IconEntry(
      name: 'Priority Medium',
      data: FontAwesomeIcons.circle,
      category: 'Task priority',
      sequence: 1,
      tags: ['priority', 'medium', 'normal', 'circle'],
    ),
    IconEntry(
      name: 'Priority High',
      data: FontAwesomeIcons.circleUp,
      category: 'Task priority',
      sequence: 2,
      tags: ['priority', 'high', 'up', 'circle'],
    ),
    IconEntry(
      name: 'Priority Urgent',
      data: FontAwesomeIcons.circle,
      category: 'Task priority',
      sequence: 3,
      tags: ['priority', 'urgent', 'critical', 'circle', 'exclamation'],
    ),
  ],
);

/// Registry icon names for task status / priority values.
abstract final class TaskFieldIconNames {
  static const statusPending = 'Status Pending';
  static const statusInProgress = 'Status In Progress';
  static const statusCompleted = 'Status Completed';
  static const statusCancelled = 'Status Cancelled';

  static const priorityLow = 'Priority Low';
  static const priorityMedium = 'Priority Medium';
  static const priorityHigh = 'Priority High';
  static const priorityUrgent = 'Priority Urgent';

  static String statusForValue(String value) => switch (value) {
        'pending' => statusPending,
        'in_progress' => statusInProgress,
        'completed' => statusCompleted,
        'cancelled' => statusCancelled,
        _ => statusPending,
      };

  static String priorityForValue(String value) => switch (value) {
        'low' => priorityLow,
        'medium' => priorityMedium,
        'high' => priorityHigh,
        'urgent' => priorityUrgent,
        _ => priorityMedium,
      };
}
