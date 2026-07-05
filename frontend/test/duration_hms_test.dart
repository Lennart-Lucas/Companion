import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/forms/duration_hms.dart';

void main() {
  group('secondsToDurationHms', () {
    test('splits total seconds', () {
      final first = secondsToDurationHms(3661);
      expect(first.hours, 1);
      expect(first.minutes, 1);
      expect(first.seconds, 1);

      final second = secondsToDurationHms(90);
      expect(second.hours, 0);
      expect(second.minutes, 1);
      expect(second.seconds, 30);
    });
  });

  group('durationHmsToSeconds', () {
    test('combines parts', () {
      expect(
        durationHmsToSeconds(hours: 1, minutes: 30, seconds: 15),
        5415,
      );
    });
  });

  group('formatDurationHms', () {
    test('pads minutes and seconds', () {
      expect(formatDurationHms(90), '0:01:30');
      expect(formatDurationHms(3661), '1:01:01');
    });
  });

  group('formatDurationChip', () {
    test('trims leading zero units and pads after the first', () {
      expect(formatDurationChip(90), '1:30');
      expect(formatDurationChip(1800), '30:00');
      expect(formatDurationChip(300), '5:00');
      expect(formatDurationChip(45), '45');
      expect(formatDurationChip(0), '0:00');
    });

    test('includes hours when non-zero', () {
      expect(formatDurationChip(3661), '1:01:01');
      expect(formatDurationChip(3600), '1:00:00');
      expect(formatDurationChip(3660), '1:01:00');
    });
  });

  group('formatDurationTargetProse', () {
    test('includes only non-zero parts', () {
      expect(formatDurationTargetProse(1800), '30 minutes');
      expect(formatDurationTargetProse(90), '1 minutes 30 seconds');
      expect(formatDurationTargetProse(3661), '1 hours 1 minutes 1 seconds');
      expect(formatDurationTargetProse(3600), '1 hours');
      expect(formatDurationTargetProse(45), '45 seconds');
      expect(formatDurationTargetProse(0), '');
    });
  });
}
