import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

void main() {
  group('formatTaskListDateHeader', () {
    test('returns weekday and short month for the current local day', () {
      final now = DateTime(2026, 6, 7, 15, 30);
      final today = DateTime(2026, 6, 7);

      expect(formatTaskListDateHeader(today, now: now), 'Sunday, Jun 7');
    });

    test('formats other days with weekday, day, month, and year', () {
      final now = DateTime(2026, 6, 7);
      final other = DateTime(2026, 6, 8);

      expect(
        formatTaskListDateHeader(other, now: now),
        'Monday, 8 June 2026',
      );
    });
  });

  group('taskListDayIsToday', () {
    test('matches only the reference calendar day', () {
      final now = DateTime(2026, 6, 7, 23, 59);
      expect(taskListDayIsToday(DateTime(2026, 6, 7), now: now), isTrue);
      expect(taskListDayIsToday(DateTime(2026, 6, 6), now: now), isFalse);
    });
  });
}
