import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_entity_picker_icons.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/icons/companion_project_field_icons.dart';
import 'package:frontend/core/icons/companion_task_field_icons.dart';

void main() {
  setUp(() {
    resetCompanionEntityIconRegistryForTest();
    setupCompanionIcons();
  });

  group('companionEntityPickerIcons', () {
    test('has no duplicate icon names', () {
      final names = companionEntityPickerIcons.entries.map((e) => e.name);
      expect(names.length, names.toSet().length);
    });

    test('includes expected categories', () {
      final categoryNames =
          companionEntityPickerIcons.categories.map((c) => c.name).toSet();
      expect(categoryNames, contains('Health & fitness'));
      expect(categoryNames, contains('Communication'));
      expect(categoryNames.length, 8);
    });
  });

  group('companionEntityIconRegistry', () {
    test('includes new entity picker icons', () {
      final registry = companionEntityIconRegistry;
      expect(registry.getIconData('Dumbbell'), isNotNull);
      expect(registry.getIconData('Trophy'), isNotNull);
      expect(registry.getIconData('Briefcase'), isNotNull);
    });

    test('includes core productivity icons', () {
      final registry = companionEntityIconRegistry;
      expect(registry.getIconData('Bullseye'), isNotNull);
      expect(registry.getIconData('Chart Line'), isNotNull);
      expect(registry.getIconData('Calendar'), isNotNull);
    });

    test('excludes task and project field semantic icons', () {
      final registry = companionEntityIconRegistry;
      expect(registry.getIconData(TaskFieldIconNames.statusPending), isNull);
      expect(registry.getIconData(TaskFieldIconNames.priorityUrgent), isNull);
      expect(
        registry.getIconData(ProjectFieldIconNames.statusActive),
        isNull,
      );
    });
  });

  group('IconRegistry.instance', () {
    test('still resolves field semantic icons globally', () {
      final registry = IconRegistry.instance;
      expect(registry.getIconData(TaskFieldIconNames.statusPending), isNotNull);
      expect(
        registry.getIconData(ProjectFieldIconNames.statusActive),
        isNotNull,
      );
      expect(registry.getIconData('Dumbbell'), isNotNull);
    });
  });
}
