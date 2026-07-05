import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/tracker_check_in_repository.dart';

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
      checkInAt: DateTime(2026, 7, 3, 8),
      checkInType: checkInType,
      logged: valueSeconds != null,
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
    name: 'Exercise',
    startDate: DateTime(2026, 7, 1),
    checkInType: TrackerCheckInType.duration,
    target: 1800,
    habitDirection: TrackerHabitDirection.build,
  );
  final now = DateTime(2026, 7, 3, 10, 30);

  test('startDurationTrackerTimer sends timer_started_at', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.duration,
      logged: false,
      skipped: false,
    );

    final updated = await startDurationTrackerTimer(
      repo,
      tracker,
      checkIn,
      now: now,
    );

    expect(repo.lastUpdated?.timerStartedAt, now.toUtc());
    expect(updated.timerStartedAt, now.toUtc());
    expect(updated.logged, isFalse);
  });

  test('stopDurationTrackerTimer accumulates elapsed seconds', () async {
    final repo = _FakeTrackerCheckInRepository();
    final started = now.subtract(const Duration(minutes: 5));
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.duration,
      logged: true,
      skipped: false,
      valueSeconds: 300,
      timerStartedAt: started.toUtc(),
    );

    final updated = await stopDurationTrackerTimer(
      repo,
      tracker,
      checkIn,
      now: now,
    );

    expect(repo.lastUpdated?.valueSeconds, 600);
    expect(updated.valueSeconds, 600);
    expect(updated.timerStartedAt, isNull);
  });

  test('trackerCheckInElapsedSeconds includes running session', () {
    final started = now.subtract(const Duration(seconds: 90));
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.duration,
      logged: true,
      skipped: false,
      valueSeconds: 60,
      timerStartedAt: started.toUtc(),
    );

    expect(trackerCheckInElapsedSeconds(checkIn, now), 150);
  });

  test('start rejects already running timer', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.duration,
      logged: false,
      skipped: false,
      timerStartedAt: now.toUtc(),
    );

    expect(
      () => startDurationTrackerTimer(repo, tracker, checkIn, now: now),
      throwsStateError,
    );
  });

  test('stop rejects when timer is not running', () async {
    final repo = _FakeTrackerCheckInRepository();
    final checkIn = TrackerCheckIn(
      id: 42,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.duration,
      logged: false,
      skipped: false,
    );

    expect(
      () => stopDurationTrackerTimer(repo, tracker, checkIn, now: now),
      throwsStateError,
    );
  });
}
