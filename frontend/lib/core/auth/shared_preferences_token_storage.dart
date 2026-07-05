import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists auth tokens in [SharedPreferences] for session restore on restart.
class SharedPreferencesTokenStorage implements TokenStorageInterface {
  static const _accessKey = 'companion_access_token';
  static const _refreshKey = 'companion_refresh_token';

  static SharedPreferences? _prefs;

  /// Must be called once before [CompanionAnvilApp.init].
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _storage {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError(
        'SharedPreferencesTokenStorage.init() must be called first.',
      );
    }
    return prefs;
  }

  @override
  Future<void> clear() async {
    await _storage.remove(_accessKey);
    await _storage.remove(_refreshKey);
  }

  @override
  Future<String?> readAccessToken() async =>
      _storage.getString(_accessKey);

  @override
  Future<String?> readRefreshToken() async =>
      _storage.getString(_refreshKey);

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.setString(_accessKey, accessToken);
    await _storage.setString(_refreshKey, refreshToken);
  }
}
