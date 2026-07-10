import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/http/companion_api_errors.dart';
import 'package:frontend/features/inputs/models/media_title.dart';

class ImdbSearchApi {
  ImdbSearchApi(this._api);

  final ApiClientService _api;

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        formatCompanionApiError(
          statusCode: response.statusCode,
          body: response.body,
          action: action,
        ),
      );
    }
  }

  Future<List<ImdbTitleSummary>> searchTitles(
    String query, {
    int limit = 20,
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query.trim());
    final response = await _api.get(
      '/imdb/search?query=$encodedQuery&limit=$limit',
    );
    _ensureSuccess(response, 'Search IMDb');
    final body = response.bodyAsMap;
    final items = body['items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ImdbTitleSummary.fromJson(item)
        else if (item is Map)
          ImdbTitleSummary.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<ImdbTitleDetail> fetchTitle(String imdbId) async {
    final normalized = normalizeImdbIdInput(imdbId);
    if (normalized == null) {
      throw Exception('Invalid IMDb ID');
    }
    final response = await _api.get('/imdb/titles/$normalized');
    _ensureSuccess(response, 'Fetch IMDb title');
    return ImdbTitleDetail.fromJson(response.bodyAsMap);
  }
}
