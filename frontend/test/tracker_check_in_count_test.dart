import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';

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
      checkInAt: DateTime(2026, 6, 15, 8),
      checkInType: checkInType,
      logged: true,
      skipped: skipped,
      completed: completed,
      countValue: countValue,
      valueSeconds: valueSeconds,
    );
    lastUpdated = updated;
    return updated;
  }
}

void main() {
  final tracker = Tracker(
    id: '1',
    name: 'Water',
    startDate: DateTime(2026, 6, 1),
    checkInType: TrackerCheckInType.count,
    target: 8,
    unit: 'glasses',
    habitDirection: TrackerHabitDirection.build,
  );
  final now = DateTime(2026, 6, 15, 12);

  test('increment logs unlogged check-in as count 1', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.count,
      logged: false,
      skipped: false,
    );

    final updated = await incrementCountTrackerCheckIn(
      repo,
      tracker,
      checkIn,
      now: now,
    );

    expect(repo.lastUpdated?.countValue, 1);
    expect(updated.countValue, 1);
    expect(
      classifyTrackerCheckIn(tracker, updated, now: now),
      TrackerCheckInOutcome.pending,
    );
  });

  test('increment bumps existing count by 1', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.count,
      logged: true,
      skipped: false,
      countValue: 2,
    );

    final updated = await incrementCountTrackerCheckIn(
      repo,
      tracker,
      checkIn,
      now: now,
    );

    expect(repo.lastUpdated?.countValue, 3);
    expect(updated.countValue, 3);
  });

  test('increment bumps count even when target already reached', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.count,
      logged: true,
      skipped: false,
      countValue: 8,
    );

    final updated = await incrementCountTrackerCheckIn(
      repo,
      tracker,
      checkIn,
      now: now,
    );

    expect(repo.lastUpdated?.countValue, 9);
    expect(updated.countValue, 9);
  });

  test('increment rejects skipped check-ins', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.count,
      logged: true,
      skipped: true,
      countValue: 2,
    );

    expect(
      () => incrementCountTrackerCheckIn(repo, tracker, checkIn, now: now),
      throwsA(isA<StateError>()),
    );
  });
}
