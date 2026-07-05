import 'package:flutter/material.dart';

import 'package:frontend/core/settings/app_settings_storage.dart';
import 'package:frontend/core/theme/app_theme.dart';

/// Holds the active theme and notifies listeners when it changes.
class AppThemeController extends ChangeNotifier {
  AppThemeController._({required AppSettingsStorage storage})
      : _storage = storage;

  static AppThemeController? _instance;

  static AppThemeController get instance {
    final controller = _instance;
    if (controller == null) {
      throw StateError(
        'AppThemeController.init() must be called before accessing instance.',
      );
    }
    return controller;
  }

  final AppSettingsStorage _storage;
  String _themeId = AppThemeId.hub;

  String get themeId => _themeId;
  ThemeData get theme => AppThemeId.themeFor(_themeId);

  static Future<void> init(AppSettingsStorage storage) async {
    final controller = AppThemeController._(storage: storage);
    final savedThemeId = storage.readThemeId();
    if (savedThemeId != null &&
        AppThemeId.options.any((option) => option.$1 == savedThemeId)) {
      controller._themeId = savedThemeId;
    }
    _instance = controller;
  }

  Future<void> setTheme(String themeId) async {
    if (_themeId == themeId) return;
    if (!AppThemeId.options.any((option) => option.$1 == themeId)) return;

    _themeId = themeId;
    await _storage.writeThemeId(themeId);
    notifyListeners();
  }
}
