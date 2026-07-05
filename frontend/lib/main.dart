import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:frontend/app/companion_app.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/auth/shared_preferences_token_storage.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/settings/app_settings_storage.dart';
import 'package:frontend/core/theme/app_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  setupCompanionIcons();
  await SharedPreferencesTokenStorage.init();
  await AppSettingsStorage.init();
  final settingsStorage = AppSettingsStorage();
  await AppThemeController.init(settingsStorage);
  await CompanionAnvilApp.init();
  CompanionAnvilApp.instance.authBloc.add(const AppStarted());
  runApp(const CompanionApp());
}
