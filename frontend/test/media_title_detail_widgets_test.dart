import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/widgets/media_title_season_progress.dart';
import 'package:frontend/features/inputs/services/media_watch_progress.dart';

void main() {
  testWidgets('MediaTitleSeasonProgress renders season labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTitleSeasonProgress(
            seasons: const [
              MediaSeasonProgress(
                seasonNumber: 1,
                watchedCount: 4,
                totalCount: 12,
                isComplete: false,
                isInProgress: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining('Season 1'), findsOneWidget);
    expect(find.textContaining('4/12'), findsOneWidget);
  });

  testWidgets('movie progress uses watch progress heading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTitleSeasonProgress(
            showMovieLabel: true,
            seasons: const [
              MediaSeasonProgress(
                seasonNumber: 0,
                watchedCount: 0,
                totalCount: 1,
                isComplete: false,
                isInProgress: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Watch progress'), findsOneWidget);
  });
}
