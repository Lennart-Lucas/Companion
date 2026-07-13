import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/icons/companion_entity_picker_icons.dart';
import 'package:frontend/core/icons/companion_event_icons.dart';
import 'package:frontend/core/icons/companion_input_icons.dart';
import 'package:frontend/core/icons/companion_project_field_icons.dart';
import 'package:frontend/core/icons/companion_task_field_icons.dart';

IconRegistry? _entityIconRegistry;

/// Icons available in goal/tracker/project/event icon pickers (excludes field
/// semantics like task status and project status).
IconRegistry get companionEntityIconRegistry {
  return _entityIconRegistry ??= () {
    final registry = IconRegistry();
    registry.registerAll(
      defaultGeneralIcons +
          defaultGoalIcons +
          defaultInputIcons +
          companionEventIcons +
          companionInputIcons +
          companionEntityPickerIcons,
    );
    return registry;
  }();
}

/// Registers default Anvil Foundry icon sets and Companion semantic aliases.
void setupCompanionIcons() {
  final registry = IconRegistry.instance;
  registry.registerAll(
    defaultGeneralIcons +
        defaultGoalIcons +
        defaultInputIcons +
        companionTaskFieldIcons +
        companionProjectFieldIcons +
        companionEventIcons +
        companionInputIcons +
        companionEntityPickerIcons,
  );

  registry.setAlias(AppIconAliases.productivity, 'Hammer');
  registry.setAlias('overview', 'House');
  registry.setAlias('event', 'Calendar');
  registry.setAlias(AppIconAliases.goal, 'Bullseye');
  registry.setAlias(AppIconAliases.tracker, 'Chart Line');
  registry.setAlias(AppIconAliases.project, 'Person Digging');
  registry.setAlias(AppIconAliases.task, 'Check Double');
  registry.setAlias(AppIconAliases.settings, 'Gear');
  registry.setAlias('inputs', 'Inbox');
  registry.setAlias('movies-tv', 'Clapperboard');
}

/// Clears the lazily built entity icon registry (for tests).
void resetCompanionEntityIconRegistryForTest() {
  _entityIconRegistry = null;
}
