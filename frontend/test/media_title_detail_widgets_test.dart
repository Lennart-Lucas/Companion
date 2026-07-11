import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/inputs/services/media_watch_progress.dart';
import 'package:frontend/features/inputs/widgets/media_title_season_episodes_panel.dart';

void main() {
  testWidgets('MediaTitleSeasonEpisodesPanel renders collapsed season headers',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTitleSeasonEpisodesPanel(
            episodes: const [
              ImdbEpisodeSummary(
                imdbId: 'tt1',
                title: 'Pilot',
                seasonNumber: 1,
                episodeNumber: 1,
              ),
              ImdbEpisodeSummary(
                imdbId: 'tt2',
                title: 'Second',
                seasonNumber: 1,
                episodeNumber: 2,
              ),
            ],
            watchEntries: const [],
          ),
        ),
      ),
    );

    expect(find.textContaining('Season 1'), findsOneWidget);
    expect(find.textContaining('0/2'), findsOneWidget);
  });

  testWidgets('tapping episode circle calls toggle callback', (tester) async {
    ImdbEpisodeSummary? toggledEpisode;
    bool? markWatched;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTitleSeasonEpisodesPanel(
            episodes: const [
              ImdbEpisodeSummary(
                imdbId: 'tt1',
                title: 'Pilot',
                seasonNumber: 1,
                episodeNumber: 1,
              ),
            ],
            watchEntries: const [],
            onToggleEpisode: (episode, watched) {
              toggledEpisode = episode;
              markWatched = watched;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(toggledEpisode?.episodeNumber, 1);
    expect(markWatched, isTrue);
  });
}
