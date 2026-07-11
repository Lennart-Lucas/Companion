import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_check_in_dialog.dart';

class _FakeTrackerCheckInRepository implements TrackerCheckInRepository {
  int? lastValueSeconds;

  @override
  Future<TrackerCheckIn> createCheckIn(
    String trackerId, {
    required DateTime checkInAt,
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    bool skipped = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<TrackerCheckIn>> fetchCheckIns(
    String trackerId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  }) async =>
      const [];

  @override
  Future<List<TrackerCheckIn>> fetchCheckInsForDay(
    String trackerId,
    DateTime day, {
    int maxCount = 100,
  }) async =>
      const [];

  @override
  Future<List<TrackerCheckIn>> fetchTrackerHistory(
    Tracker tracker, {
    DateTime? now,
    int maxCount = 5000,
  }) async =>
      const [];

  @override
  Future<void> skipCheckIn(String trackerId, int checkInId) async {}

  @override
  Future<TrackerCheckIn> updateCheckIn(
    String trackerId,
    int checkInId, {
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    DateTime? timerStartedAt,
    bool skipped = false,
  }) async {
    lastValueSeconds = valueSeconds;
    return TrackerCheckIn(
      id: checkInId,
      checkInAt: DateTime(2026, 7, 3, 8),
      checkInType: checkInType,
      logged: valueSeconds != null,
      skipped: skipped,
      valueSeconds: valueSeconds,
    );
  }
}

void main() {
  testWidgets('duration check-in dialog shows H:M:S field and saves seconds', (
    WidgetTester tester,
  ) async {
    final repo = _FakeTrackerCheckInRepository();
    final tracker = Tracker(
      id: '1',
      name: 'Exercise',
      startDate: DateTime(2026, 7, 1),
      checkInType: TrackerCheckInType.duration,
      target: 3600,
    );
    final checkIn = TrackerCheckIn(
      id: 9,
      checkInAt: DateTime(2026, 7, 3, 8),
      checkInType: TrackerCheckInType.duration,
      logged: true,
      skipped: false,
      valueSeconds: 3661,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showTrackerCheckInDialog(
                context: context,
                tracker: tracker,
                repository: repo,
                checkIn: checkIn,
                checkInAt: checkIn.checkInAt,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('01'), findsNWidgets(2));
    expect(find.text('Minutes'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.lastValueSeconds, 3661);
  });
}
