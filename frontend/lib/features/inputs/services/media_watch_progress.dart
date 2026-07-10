import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/models/media_watch_entry.dart';

class ImdbEpisodeSummary {
  const ImdbEpisodeSummary({
    required this.imdbId,
    required this.title,
    required this.seasonNumber,
    required this.episodeNumber,
    this.runtimeMinutes,
    this.rating,
  });

  final String imdbId;
  final String title;
  final int seasonNumber;
  final int episodeNumber;
  final int? runtimeMinutes;
  final double? rating;

  factory ImdbEpisodeSummary.fromJson(Map<String, dynamic> json) {
    return ImdbEpisodeSummary(
      imdbId: json['imdb_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      seasonNumber: MediaTitle.intFromJson(json['season_number']) ?? 0,
      episodeNumber: MediaTitle.intFromJson(json['episode_number']) ?? 0,
      runtimeMinutes: MediaTitle.intFromJson(json['runtime_minutes']),
      rating: MediaTitle.doubleFromJson(json['rating']),
    );
  }
}

class MediaSeasonProgress {
  const MediaSeasonProgress({
    required this.seasonNumber,
    required this.watchedCount,
    required this.totalCount,
    required this.isComplete,
    required this.isInProgress,
  });

  final int seasonNumber;
  final int watchedCount;
  final int totalCount;
  final bool isComplete;
  final bool isInProgress;

  String get label {
    if (isComplete) return '$watchedCount/$totalCount Complete';
    if (isInProgress) return '$watchedCount/$totalCount Watching';
    return '0/$totalCount Not started';
  }

  double get fraction =>
      totalCount == 0 ? 0 : watchedCount.clamp(0, totalCount) / totalCount;
}

Set<String> _watchedEpisodeKeys(List<MediaWatchEntry> entries) {
  return {
    for (final entry in entries)
      if (entry.seasonNumber != null && entry.episodeNumber != null)
        '${entry.seasonNumber}:${entry.episodeNumber}',
  };
}

List<MediaSeasonProgress> computeSeasonProgress(
  List<ImdbEpisodeSummary> episodes,
  List<MediaWatchEntry> watchEntries,
) {
  final watched = _watchedEpisodeKeys(watchEntries);
  final bySeason = <int, int>{};
  final watchedBySeason = <int, int>{};

  for (final episode in episodes) {
    bySeason[episode.seasonNumber] = (bySeason[episode.seasonNumber] ?? 0) + 1;
    final key = '${episode.seasonNumber}:${episode.episodeNumber}';
    if (watched.contains(key)) {
      watchedBySeason[episode.seasonNumber] =
          (watchedBySeason[episode.seasonNumber] ?? 0) + 1;
    }
  }

  final seasons = bySeason.keys.toList()..sort();
  return [
    for (final season in seasons)
      () {
        final total = bySeason[season] ?? 0;
        final watchedCount = watchedBySeason[season] ?? 0;
        final isComplete = total > 0 && watchedCount >= total;
        final isInProgress = watchedCount > 0 && !isComplete;
        return MediaSeasonProgress(
          seasonNumber: season,
          watchedCount: watchedCount,
          totalCount: total,
          isComplete: isComplete,
          isInProgress: isInProgress,
        );
      }(),
  ];
}

ImdbEpisodeSummary? findNextUnwatchedEpisode(
  List<ImdbEpisodeSummary> episodes,
  List<MediaWatchEntry> watchEntries,
) {
  final watched = _watchedEpisodeKeys(watchEntries);
  final sorted = [...episodes]
    ..sort((a, b) {
      final seasonCompare = a.seasonNumber.compareTo(b.seasonNumber);
      if (seasonCompare != 0) return seasonCompare;
      return a.episodeNumber.compareTo(b.episodeNumber);
    });

  for (final episode in sorted) {
    final key = '${episode.seasonNumber}:${episode.episodeNumber}';
    if (!watched.contains(key)) return episode;
  }
  return null;
}

bool isMovieWatched(List<MediaWatchEntry> watchEntries) {
  return watchEntries.any(
    (entry) => entry.seasonNumber == null && entry.episodeNumber == null,
  );
}

MediaSeasonProgress? movieWatchProgress(List<MediaWatchEntry> watchEntries) {
  final watched = isMovieWatched(watchEntries);
  return MediaSeasonProgress(
    seasonNumber: 0,
    watchedCount: watched ? 1 : 0,
    totalCount: 1,
    isComplete: watched,
    isInProgress: false,
  );
}
