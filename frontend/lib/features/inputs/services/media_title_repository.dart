import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/http/companion_api_errors.dart';
import 'package:frontend/features/inputs/models/media_title.dart';

class MediaTitleRepository {
  MediaTitleRepository(this._api);

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

  Future<MediaTitle> createFromImdbId(String imdbId) async {
    final normalized = normalizeImdbIdInput(imdbId);
    if (normalized == null) {
      throw Exception('Invalid IMDb ID');
    }
    final response = await _api.post(
      '/media-titles',
      body: {'imdb_id': normalized},
    );
    if (response.statusCode == 409) {
      throw MediaTitleAlreadyExistsException(
        extractCompanionApiErrorDetail(response.body) ??
            'This title is already in your library',
      );
    }
    _ensureSuccess(response, 'Add media title');
    return MediaTitle.fromJson(response.bodyAsMap);
  }
}

class MediaTitleAlreadyExistsException implements Exception {
  MediaTitleAlreadyExistsException(this.message);

  final String message;

  @override
  String toString() => message;
}
