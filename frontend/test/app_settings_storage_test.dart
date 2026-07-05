import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/settings/app_settings_storage.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsStorage', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppSettingsStorage.init();
    });

    test('round-trips theme id', () async {
      final storage = AppSettingsStorage();

      expect(storage.readThemeId(), isNull);

      await storage.writeThemeId(AppThemeId.abyss);
      expect(storage.readThemeId(), AppThemeId.abyss);

      await storage.writeThemeId(AppThemeId.nebula);
      expect(storage.readThemeId(), AppThemeId.nebula);
    });
  });
}
