import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/http/companion_api_errors.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/services/media_watch_progress.dart';

class MediaEpisodesApi {
  MediaEpisodesApi(this._api);

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

  Future<List<ImdbEpisodeSummary>> fetchAllEpisodes(String imdbId) async {
    final normalized = normalizeImdbIdInput(imdbId);
    if (normalized == null) {
      throw Exception('Invalid IMDb ID');
    }

    final episodes = <ImdbEpisodeSummary>[];
    String? pageToken;
    do {
      final tokenQuery = pageToken != null
          ? '&page_token=${Uri.encodeQueryComponent(pageToken)}'
          : '';
      final response = await _api.get(
        '/imdb/titles/$normalized/episodes?page_size=100$tokenQuery',
      );
      _ensureSuccess(response, 'Fetch episodes');
      final body = response.bodyAsMap;
      final items = body['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            episodes.add(ImdbEpisodeSummary.fromJson(item));
          } else if (item is Map) {
            episodes.add(
              ImdbEpisodeSummary.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      pageToken = body['next_page_token'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);

    episodes.sort((a, b) {
      final seasonCompare = a.seasonNumber.compareTo(b.seasonNumber);
      if (seasonCompare != 0) return seasonCompare;
      return a.episodeNumber.compareTo(b.episodeNumber);
    });
    return episodes;
  }
}

MediaEpisodesApi defaultMediaEpisodesApi() =>
    MediaEpisodesApi(CompanionAnvilApp.instance.apiClient);
