import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:http/http.dart' as http;

/// Result of a one-shot `GET /health` check.
class ApiPingResult {
  const ApiPingResult({
    required this.reachable,
    required this.healthUri,
    this.error,
  });

  final bool reachable;
  final Uri healthUri;
  final String? error;
}

/// Monitors device connectivity and API reachability for offline mode.
class CompanionConnectivityService {
  CompanionConnectivityService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _anvil = AnvilConnectivityService(
          checker: _connectivityChecker(httpClient ?? http.Client()),
          interval: const Duration(seconds: 15),
        );

  final http.Client _httpClient;
  final AnvilConnectivityService _anvil;

  static Future<bool> Function() _connectivityChecker(http.Client client) {
    return () async {
      final result = await pingApi(httpClient: client);
      return result.reachable && result.error == null;
    };
  }

  /// One-shot GET `/health` against [AppConfig.apiBaseUrl].
  ///
  /// [reachable] is true when any HTTP response is received (the server is up).
  /// [error] is set when the status is not 200 or a network error occurred.
  static Future<ApiPingResult> pingApi({http.Client? httpClient}) async {
    final healthUri = AppConfig.apiHealthUri;
    final client = httpClient ?? http.Client();
    final closeClient = httpClient == null;
    try {
      final response =
          await client.get(healthUri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return ApiPingResult(reachable: true, healthUri: healthUri);
      }
      return ApiPingResult(
        reachable: true,
        healthUri: healthUri,
        error: 'Unexpected HTTP ${response.statusCode}',
      );
    } catch (e) {
      return ApiPingResult(
        reachable: false,
        healthUri: healthUri,
        error: e.toString(),
      );
    } finally {
      if (closeClient) client.close();
    }
  }

  AnvilConnectivityService get anvil => _anvil;

  bool get isOnline => _anvil.isOnline;

  Stream<AnvilConnectivityStatus> get statusStream => _anvil.statusStream;

  void startMonitoring() => _anvil.startMonitoring();

  void stopMonitoring() => _anvil.stopMonitoring();

  Future<AnvilConnectivityStatus> check() => _anvil.check();

  void dispose() {
    _anvil.dispose();
    _httpClient.close();
  }
}
