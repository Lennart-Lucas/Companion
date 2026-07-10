import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/http/companion_api_errors.dart';
import 'package:frontend/features/inputs/models/media_watch_entry.dart';
import 'package:frontend/features/inputs/services/media_watch_progress.dart';

abstract class MediaWatchRepository {
  Future<List<MediaWatchEntry>> fetchWatchEntries(String mediaTitleId);

  Future<MediaWatchEntry> logEpisode(
    String mediaTitleId, {
    required int seasonNumber,
    required int episodeNumber,
    String? episodeImdbId,
    String? episodeTitle,
    DateTime? watchedAt,
  });

  Future<MediaWatchEntry> markMovieWatched(
    String mediaTitleId, {
    DateTime? watchedAt,
  });

  Future<MediaWatchEntry> logNextEpisode(
    String mediaTitleId,
    List<ImdbEpisodeSummary> episodes,
    List<MediaWatchEntry> existingEntries, {
    DateTime? watchedAt,
  });

  Future<void> deleteWatchEntry(String mediaTitleId, String entryId);
}

class HttpMediaWatchRepository implements MediaWatchRepository {
  HttpMediaWatchRepository(this._api);

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

  MediaWatchEntry _parseEntry(Map<String, dynamic> json) =>
      MediaWatchEntry.fromJson(json);

  @override
  Future<List<MediaWatchEntry>> fetchWatchEntries(String mediaTitleId) async {
    final response = await _api.get('/media-titles/$mediaTitleId/watch-entries');
    if (response.statusCode == 404) {
      // Older API builds without watch tracking — treat as empty log.
      return const [];
    }
    _ensureSuccess(response, 'Fetch watch entries');
    final body = response.bodyAsMap;
    final items = body['items'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          _parseEntry(item)
        else if (item is Map)
          _parseEntry(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<MediaWatchEntry> logEpisode(
    String mediaTitleId, {
    required int seasonNumber,
    required int episodeNumber,
    String? episodeImdbId,
    String? episodeTitle,
    DateTime? watchedAt,
  }) async {
    final response = await _api.post(
      '/media-titles/$mediaTitleId/watch-entries',
      body: {
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        ?'episode_imdb_id': episodeImdbId,
        ?'episode_title': episodeTitle,
        ?'watched_at': watchedAt?.toUtc().toIso8601String(),
      },
    );
    _ensureSuccess(response, 'Log episode');
    return _parseEntry(response.bodyAsMap);
  }

  @override
  Future<MediaWatchEntry> markMovieWatched(
    String mediaTitleId, {
    DateTime? watchedAt,
  }) async {
    final response = await _api.post(
      '/media-titles/$mediaTitleId/watch-entries',
      body: {
        ?'watched_at': watchedAt?.toUtc().toIso8601String(),
      },
    );
    _ensureSuccess(response, 'Mark movie watched');
    return _parseEntry(response.bodyAsMap);
  }

  @override
  Future<MediaWatchEntry> logNextEpisode(
    String mediaTitleId,
    List<ImdbEpisodeSummary> episodes,
    List<MediaWatchEntry> existingEntries, {
    DateTime? watchedAt,
  }) async {
    final next = findNextUnwatchedEpisode(episodes, existingEntries);
    if (next == null) {
      throw StateError('No unwatched episodes remain');
    }
    return logEpisode(
      mediaTitleId,
      seasonNumber: next.seasonNumber,
      episodeNumber: next.episodeNumber,
      episodeImdbId: next.imdbId,
      episodeTitle: next.title,
      watchedAt: watchedAt,
    );
  }

  @override
  Future<void> deleteWatchEntry(String mediaTitleId, String entryId) async {
    final response = await _api.delete(
      '/media-titles/$mediaTitleId/watch-entries/$entryId',
    );
    _ensureSuccess(response, 'Delete watch entry');
  }
}

MediaWatchRepository defaultMediaWatchRepository() =>
    HttpMediaWatchRepository(CompanionAnvilApp.instance.apiClient);
