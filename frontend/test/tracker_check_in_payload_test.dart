import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/tracker_check_in_payload.dart';

void main() {
  test('trackerCheckInLogPayload builds count body', () {
    expect(
      trackerCheckInLogPayload(
        checkInType: TrackerCheckInType.count,
        countValue: 6,
      ),
      {'count_value': 6},
    );
  });

  test('trackerCheckInLogPayload builds timer start body', () {
    final started = DateTime.utc(2026, 7, 3, 10);
    expect(
      trackerCheckInLogPayload(
        checkInType: TrackerCheckInType.duration,
        timerStartedAt: started,
      ),
      {'timer_started_at': started.toIso8601String()},
    );
  });

  test('trackerCheckInCreatePayload includes check_in_at', () {
    final at = DateTime.utc(2026, 5, 22, 12);
    final payload = trackerCheckInCreatePayload(
      checkInAt: at,
      checkInType: TrackerCheckInType.task,
      completed: true,
    );

    expect(payload['check_in_at'], at.toIso8601String());
    expect(payload['completed'], isTrue);
  });
}
