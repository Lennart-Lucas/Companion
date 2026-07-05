import 'package:shared_preferences/shared_preferences.dart';

/// Persists user-facing app settings in [SharedPreferences].
class AppSettingsStorage {
  static const _themeIdKey = 'companion_theme_id';

  static SharedPreferences? _prefs;

  /// Must be called once before reading or writing settings.
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _storage {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('AppSettingsStorage.init() must be called first.');
    }
    return prefs;
  }

  String? readThemeId() => _storage.getString(_themeIdKey);

  Future<void> writeThemeId(String themeId) async {
    await _storage.setString(_themeIdKey, themeId);
  }
}
