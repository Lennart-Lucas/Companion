import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';

void main() {
  group('taskListWeekStart', () {
    test('returns Monday for a Wednesday', () {
      final wednesday = DateTime(2026, 6, 10);
      expect(taskListWeekStart(wednesday), DateTime(2026, 6, 8));
    });

    test('returns same day for a Monday', () {
      final monday = DateTime(2026, 6, 8);
      expect(taskListWeekStart(monday), DateTime(2026, 6, 8));
    });

    test('returns Monday for a Sunday', () {
      final sunday = DateTime(2026, 6, 14);
      expect(taskListWeekStart(sunday), DateTime(2026, 6, 8));
    });
  });

  group('taskListWeekDays', () {
    test('returns Mon through Sun', () {
      final weekStart = DateTime(2026, 6, 8);
      final days = taskListWeekDays(weekStart);

      expect(days, hasLength(7));
      expect(days.first, DateTime(2026, 6, 8));
      expect(days.last, DateTime(2026, 6, 14));
      expect(days.map(taskListWeekdayAbbrev).toList(), [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ]);
    });
  });

  group('taskListWeekdayAbbrev', () {
    test('returns abbreviated weekday names', () {
      expect(taskListWeekdayAbbrev(DateTime(2026, 6, 8)), 'Mon');
      expect(taskListWeekdayAbbrev(DateTime(2026, 6, 12)), 'Fri');
    });
  });

  group('formatTaskListWeekTitle', () {
    test('uses month and year of week start', () {
      expect(formatTaskListWeekTitle(DateTime(2026, 6, 8)), 'June 2026');
    });

    test('uses first day of week when week spans month boundary', () {
      expect(formatTaskListWeekTitle(DateTime(2025, 12, 29)), 'December 2025');
    });
  });

  group('taskListMonthStart', () {
    test('normalizes to first day of month', () {
      expect(taskListMonthStart(DateTime(2026, 6, 15)), DateTime(2026, 6, 1));
    });
  });

  group('taskListMonthGridDays', () {
    test('returns 42 Monday-first cells for June 2026', () {
      final days = taskListMonthGridDays(DateTime(2026, 6, 1));

      expect(days, hasLength(42));
      expect(days.first, DateTime(2026, 6, 1)); // June 1 is Monday
      expect(days.any((d) => d == DateTime(2026, 5, 31)), isFalse);
      expect(days.contains(DateTime(2026, 6, 30)), isTrue);
    });

    test('includes leading outside-month days when month does not start on Monday', () {
      final days = taskListMonthGridDays(DateTime(2026, 7, 1));

      expect(days.first, DateTime(2026, 6, 29)); // Monday before July 1
      expect(days.contains(DateTime(2026, 7, 1)), isTrue);
    });

    test('taskListDayInMonth identifies in-month vs outside-month cells', () {
      final month = DateTime(2026, 7, 1);
      expect(taskListDayInMonth(DateTime(2026, 6, 29), month), isFalse);
      expect(taskListDayInMonth(DateTime(2026, 7, 15), month), isTrue);
    });
  });

  group('taskListWeekPageForDay', () {
    test('returns initial page for day in anchor week', () {
      final listToday = DateTime(2026, 6, 10);
      expect(
        taskListWeekPageForDay(day: DateTime(2026, 6, 12), listToday: listToday),
        10000,
      );
    });

    test('returns offset page for future week', () {
      final listToday = DateTime(2026, 6, 10);
      expect(
        taskListWeekPageForDay(day: DateTime(2026, 6, 19), listToday: listToday),
        10001,
      );
    });

    test('returns offset page across month boundary', () {
      final listToday = DateTime(2026, 6, 10);
      expect(
        taskListWeekPageForDay(day: DateTime(2026, 7, 1), listToday: listToday),
        10003,
      );
    });
  });
}
