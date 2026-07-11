import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';

void main() {
  group('TaskListHorizon', () {
    test('forLocalDays spans local days through end of day UTC', () {
      final horizon = TaskListHorizon.forLocalDays(
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 3),
      );

      expect(horizon.from, DateTime(2026, 6, 1).toUtc());
      expect(
        horizon.to,
        DateTime(2026, 6, 3, 23, 59, 59).toUtc(),
      );
    });

    test('aroundToday includes past and future days', () {
      const pastDays = 7;
      const futureDays = 14;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final horizon = TaskListHorizon.aroundToday(
        pastDays: pastDays,
        futureDays: futureDays,
      );

      final localFrom = horizon.from.toLocal();
      final localTo = horizon.to.toLocal();
      expect(
        DateTime(localFrom.year, localFrom.month, localFrom.day),
        today.subtract(const Duration(days: pastDays)),
      );
      expect(
        DateTime(localTo.year, localTo.month, localTo.day),
        today.add(const Duration(days: futureDays)),
      );
    });

    test('extendBackward and extendForward widen the window', () {
      final initial = TaskListHorizon.forLocalDays(
        DateTime(2026, 6, 10),
        DateTime(2026, 6, 20),
      );

      final earlier = initial.extendBackward(days: 5);
      expect(
        DateTime(
          earlier.from.toLocal().year,
          earlier.from.toLocal().month,
          earlier.from.toLocal().day,
        ),
        DateTime(2026, 6, 5),
      );

      final later = initial.extendForward(days: 5);
      expect(
        DateTime(
          later.to.toLocal().year,
          later.to.toLocal().month,
          later.to.toLocal().day,
        ),
        DateTime(2026, 6, 25),
      );
    });
  });

  group('taskListDateInHorizon', () {
    test('includes dates within the inclusive window', () {
      final horizon = TaskListHorizon.forLocalDays(
        DateTime(2026, 6, 10),
        DateTime(2026, 6, 20),
      );

      expect(
        taskListDateInHorizon(DateTime(2026, 6, 15, 12), horizon),
        isTrue,
      );
      expect(
        taskListDateInHorizon(DateTime(2026, 6, 9), horizon),
        isFalse,
      );
      expect(
        taskListDateInHorizon(DateTime(2026, 6, 21), horizon),
        isFalse,
      );
    });
  });
}
