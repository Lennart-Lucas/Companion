import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';

class _FakeTrackerCheckInRepository implements TrackerCheckInRepository {
  TrackerCheckIn? lastUpdated;

  @override
  Future<TrackerCheckIn> createCheckIn(
    String trackerId, {
    required DateTime checkInAt,
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    DateTime? timerStartedAt,
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
    final updated = TrackerCheckIn(
      id: checkInId,
      checkInAt: DateTime(2026, 6, 7),
      checkInType: checkInType,
      logged: true,
      skipped: skipped,
      completed: completed,
      countValue: countValue,
      valueSeconds: valueSeconds,
      timerStartedAt: timerStartedAt,
    );
    lastUpdated = updated;
    return updated;
  }
}

void main() {
  final tracker = Tracker(
    id: '1',
    name: 'Meditation',
    startDate: DateTime(2026, 6, 1),
    checkInType: TrackerCheckInType.task,
    habitDirection: TrackerHabitDirection.build,
  );
  final now = DateTime(2026, 6, 8);

  test('toggle marks pending today check-in as done', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.task,
      logged: false,
      skipped: false,
    );

    final updated = await toggleTaskTrackerCheckIn(
      repo,
      tracker,
      checkIn,
      now: now,
    );

    expect(repo.lastUpdated?.completed, isTrue);
    expect(
      classifyTrackerCheckIn(tracker, updated, now: now),
      TrackerCheckInOutcome.succeeded,
    );
  });

  test('toggle marks missed check-in as done', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(2026, 6, 7),
      checkInType: TrackerCheckInType.task,
      logged: false,
      skipped: false,
    );

    final updated = await toggleTaskTrackerCheckIn(
      repo,
      tracker,
      checkIn,
      now: now,
    );

    expect(repo.lastUpdated?.completed, isTrue);
    expect(updated.completed, isTrue);
    expect(
      classifyTrackerCheckIn(tracker, updated, now: now),
      TrackerCheckInOutcome.succeeded,
    );
  });

  test('toggle marks done check-in as not done', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(2026, 6, 7),
      checkInType: TrackerCheckInType.task,
      logged: true,
      skipped: false,
      completed: true,
    );

    final updated = await toggleTaskTrackerCheckIn(
      repo,
      tracker,
      checkIn,
      now: now,
    );

    expect(repo.lastUpdated?.completed, isFalse);
    expect(updated.completed, isFalse);
    expect(
      classifyTrackerCheckIn(tracker, updated, now: now),
      TrackerCheckInOutcome.missed,
    );
  });
}
