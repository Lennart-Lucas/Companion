import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/icons/companion_event_icons.dart';
import 'package:frontend/core/icons/companion_project_field_icons.dart';
import 'package:frontend/core/icons/companion_task_field_icons.dart';

/// Registers default Anvil Foundry icon sets and Companion semantic aliases.
void setupCompanionIcons() {
  final registry = IconRegistry.instance;
  registry.registerAll(
    defaultGeneralIcons +
        defaultGoalIcons +
        defaultInputIcons +
        companionTaskFieldIcons +
        companionProjectFieldIcons +
        companionEventIcons,
  );

  registry.setAlias(AppIconAliases.productivity, 'Hammer');
  registry.setAlias('overview', 'House');
  registry.setAlias('event', 'Calendar');
  registry.setAlias(AppIconAliases.goal, 'Bullseye');
  registry.setAlias(AppIconAliases.tracker, 'Chart Line');
  registry.setAlias(AppIconAliases.project, 'Person Digging');
  registry.setAlias(AppIconAliases.task, 'Check Double');
  registry.setAlias(AppIconAliases.settings, 'Gear');
}
