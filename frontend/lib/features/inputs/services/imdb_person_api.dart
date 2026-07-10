import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/http/companion_api_errors.dart';
import 'package:frontend/features/inputs/models/media_title.dart';

/// Must match backend `page_size` max in `imdb.py` (le=50).
const kImdbFilmographyPageSize = 50;

class ImdbFilmographyEntry {
  const ImdbFilmographyEntry({
    required this.imdbId,
    required this.name,
    this.mediaType,
    this.year,
    this.posterUrl,
    this.category,
  });

  final String imdbId;
  final String name;
  final String? mediaType;
  final int? year;
  final String? posterUrl;
  final String? category;

  factory ImdbFilmographyEntry.fromJson(Map<String, dynamic> json) {
    return ImdbFilmographyEntry(
      imdbId: json['imdb_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mediaType: json['media_type'] as String?,
      year: MediaTitle.intFromJson(json['year']),
      posterUrl: json['poster_url'] as String?,
      category: json['category'] as String?,
    );
  }
}

class ImdbPersonApi {
  ImdbPersonApi(this._api);

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

  Future<List<ImdbFilmographyEntry>> fetchFilmography(String imdbNameId) async {
    final normalized = imdbNameId.trim().toLowerCase();
    final entries = <ImdbFilmographyEntry>[];
    String? pageToken;
    do {
      final tokenQuery = pageToken != null
          ? '&page_token=${Uri.encodeQueryComponent(pageToken)}'
          : '';
      final response = await _api.get(
        '/imdb/names/$normalized/filmography?page_size=$kImdbFilmographyPageSize$tokenQuery',
      );
      _ensureSuccess(response, 'Fetch actor filmography');
      final body = response.bodyAsMap;
      final items = body['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            entries.add(ImdbFilmographyEntry.fromJson(item));
          } else if (item is Map) {
            entries.add(
              ImdbFilmographyEntry.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      pageToken = body['next_page_token'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);

    return entries;
  }
}

ImdbPersonApi defaultImdbPersonApi() =>
    ImdbPersonApi(CompanionAnvilApp.instance.apiClient);
