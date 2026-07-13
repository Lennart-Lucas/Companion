import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/shared/services/quota_check_in_display.dart';

void main() {
  group('computeQuotaCheckInDisplayAt', () {
    final periodEnd = DateTime.utc(2026, 5, 31, 9);

    test('failed slots anchor to period end', () {
      final at = computeQuotaCheckInDisplayAt(
        checkInAt: DateTime.utc(2026, 5, 19, 9),
        spawnedAt: DateTime.utc(2026, 5, 19, 9),
        lockedAt: periodEnd,
        slotKind: 'failed',
        periodEndAt: periodEnd,
        now: DateTime.utc(2026, 6, 1),
      );
      expect(at, periodEnd);
    });

    test('locked slots anchor to locked day', () {
      final locked = DateTime.utc(2026, 5, 28, 9);
      final at = computeQuotaCheckInDisplayAt(
        checkInAt: DateTime.utc(2026, 5, 19, 9),
        spawnedAt: DateTime.utc(2026, 5, 19, 9),
        lockedAt: locked,
        slotKind: 'locked',
        periodEndAt: periodEnd,
        now: DateTime.utc(2026, 5, 30),
      );
      expect(at, locked);
    });

    test('active slots drift to today', () {
      final at = computeQuotaCheckInDisplayAt(
        checkInAt: DateTime.utc(2026, 5, 19, 9),
        spawnedAt: DateTime.utc(2026, 5, 19, 9),
        lockedAt: null,
        slotKind: 'active',
        periodEndAt: periodEnd,
        now: DateTime.utc(2026, 5, 25, 12),
      );
      expect(at.year, 2026);
      expect(at.month, 5);
      expect(at.day, 25);
    });
  });

  test('quotaCheckInFailed', () {
    expect(quotaCheckInFailed(slotKind: 'failed'), isTrue);
    expect(quotaCheckInFailed(slotKind: 'active', failed: false), isFalse);
    expect(quotaCheckInFailed(slotKind: 'active', failed: true), isTrue);
  });
}
