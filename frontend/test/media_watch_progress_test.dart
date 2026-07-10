import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/models/media_watch_entry.dart';
import 'package:frontend/features/inputs/services/media_watch_progress.dart';

void main() {
  group('isTvMediaType', () {
    test('detects TV series variants', () {
      expect(isTvMediaType('tvSeries'), isTrue);
      expect(isTvMediaType('tv_series'), isTrue);
      expect(isTvMediaType('tvMiniSeries'), isTrue);
      expect(isTvMediaType('movie'), isFalse);
    });
  });

  group('computeSeasonProgress', () {
    test('counts watched episodes per season', () {
      final episodes = [
        const ImdbEpisodeSummary(
          imdbId: 'tt1',
          title: 'Pilot',
          seasonNumber: 1,
          episodeNumber: 1,
        ),
        const ImdbEpisodeSummary(
          imdbId: 'tt2',
          title: 'Second',
          seasonNumber: 1,
          episodeNumber: 2,
        ),
        const ImdbEpisodeSummary(
          imdbId: 'tt3',
          title: 'S2E1',
          seasonNumber: 2,
          episodeNumber: 1,
        ),
      ];
      final entries = [
        MediaWatchEntry(
          id: '1',
          mediaTitleId: '9',
          name: 'Pilot',
          seasonNumber: 1,
          episodeNumber: 1,
          watchedAt: DateTime.utc(2026, 1, 1),
        ),
      ];

      final progress = computeSeasonProgress(episodes, entries);
      expect(progress, hasLength(2));
      expect(progress[0].seasonNumber, 1);
      expect(progress[0].watchedCount, 1);
      expect(progress[0].totalCount, 2);
      expect(progress[0].isInProgress, isTrue);
      expect(progress[1].watchedCount, 0);
    });
  });

  group('findNextUnwatchedEpisode', () {
    test('returns earliest unwatched episode', () {
      final episodes = [
        const ImdbEpisodeSummary(
          imdbId: 'tt1',
          title: 'Pilot',
          seasonNumber: 1,
          episodeNumber: 1,
        ),
        const ImdbEpisodeSummary(
          imdbId: 'tt2',
          title: 'Second',
          seasonNumber: 1,
          episodeNumber: 2,
        ),
      ];
      final entries = [
        MediaWatchEntry(
          id: '1',
          mediaTitleId: '9',
          name: 'Pilot',
          seasonNumber: 1,
          episodeNumber: 1,
          watchedAt: DateTime.utc(2026, 1, 1),
        ),
      ];

      final next = findNextUnwatchedEpisode(episodes, entries);
      expect(next?.episodeNumber, 2);
    });
  });

  group('groupEpisodesBySeason', () {
    test('groups and sorts episodes within each season', () {
      final episodes = [
        const ImdbEpisodeSummary(
          imdbId: 'tt2',
          title: 'Second',
          seasonNumber: 1,
          episodeNumber: 2,
        ),
        const ImdbEpisodeSummary(
          imdbId: 'tt3',
          title: 'S2E1',
          seasonNumber: 2,
          episodeNumber: 1,
        ),
        const ImdbEpisodeSummary(
          imdbId: 'tt1',
          title: 'Pilot',
          seasonNumber: 1,
          episodeNumber: 1,
        ),
      ];

      final grouped = groupEpisodesBySeason(episodes);
      expect(grouped.keys, [1, 2]);
      expect(grouped[1]!.map((e) => e.episodeNumber).toList(), [1, 2]);
    });
  });

  group('countWatchedTvEpisodes', () {
    test('counts only episode-level watch entries', () {
      final entries = [
        MediaWatchEntry(
          id: '1',
          mediaTitleId: '9',
          name: 'Pilot',
          seasonNumber: 1,
          episodeNumber: 1,
          watchedAt: DateTime.utc(2026, 1, 1),
        ),
        MediaWatchEntry(
          id: '2',
          mediaTitleId: '9',
          name: 'Movie',
          watchedAt: DateTime.utc(2026, 1, 2),
        ),
      ];

      expect(countWatchedTvEpisodes(entries), 1);
    });
  });

  group('movieWatchProgress', () {
    test('reports watched movie as complete', () {
      final entries = [
        MediaWatchEntry(
          id: '1',
          mediaTitleId: '9',
          name: 'Watched',
          watchedAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      final progress = movieWatchProgress(entries);
      expect(progress?.isComplete, isTrue);
      expect(progress?.watchedCount, 1);
    });
  });
}
