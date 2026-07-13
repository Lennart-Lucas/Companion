import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';

void main() {
  group('projectTaskListHorizon', () {
    test('returns full project span when only project dates are set', () {
      final horizon = projectTaskListHorizon(
        project: Project(
          id: '1',
          name: 'P',
          status: 'active',
          startDate: DateTime(2026, 6, 1),
          deadline: DateTime(2026, 6, 30),
        ),
        tasks: const [],
      );

      expect(horizon, isNotNull);
      expect(horizon!.localFromDay, DateTime(2026, 6, 1));
      expect(horizon.localToDay, DateTime(2026, 6, 30));
    });

    test('returns span between first and last task when project has no dates', () {
      final horizon = projectTaskListHorizon(
        project: Project(id: '1', name: 'P', status: 'active'),
        tasks: [
          Task(
            id: 'a',
            name: 'Later',
            status: 'pending',
            plannedAt: DateTime(2026, 8, 20),
          ),
          Task(
            id: 'b',
            name: 'Earlier',
            status: 'pending',
            plannedAt: DateTime(2026, 6, 15),
          ),
        ],
      );

      expect(horizon, isNotNull);
      expect(horizon!.localFromDay, DateTime(2026, 6, 15));
      expect(horizon.localToDay, DateTime(2026, 8, 20));
    });

    test('extends project span when a task falls outside project dates', () {
      final today = DateTime(2026, 7, 5);
      final horizon = projectTaskListHorizon(
        project: Project(
          id: '1',
          name: 'P',
          status: 'active',
          startDate: DateTime(2026, 6, 1),
          deadline: DateTime(2026, 6, 30),
        ),
        tasks: [
          Task(
            id: 'a',
            name: 'Outside',
            status: 'pending',
            plannedAt: DateTime(2026, 7, 5),
          ),
        ],
        today: today,
      );

      expect(horizon, isNotNull);
      expect(horizon!.localFromDay, DateTime(2026, 6, 1));
      expect(horizon.localToDay, DateTime(2026, 7, 5));
    });

    test('returns null when only undated tasks exist', () {
      final horizon = projectTaskListHorizon(
        project: Project(id: '1', name: 'P', status: 'active'),
        tasks: [
          Task(id: 'a', name: 'No date', status: 'pending'),
        ],
      );

      expect(horizon, isNull);
    });

    test('extends past span through today for open overdue tasks', () {
      final today = DateTime(2026, 6, 15);
      final horizon = projectTaskListHorizon(
        project: Project(
          id: '1',
          name: 'P',
          status: 'active',
          startDate: DateTime(2026, 5, 1),
          deadline: DateTime(2026, 5, 31),
        ),
        tasks: [
          Task(
            id: 'a',
            name: 'Overdue',
            status: 'pending',
            plannedAt: DateTime(2026, 5, 10),
          ),
        ],
        today: today,
      );

      expect(horizon, isNotNull);
      expect(horizon!.localFromDay, DateTime(2026, 5, 1));
      expect(horizon.localToDay, today);
    });

    test('does not extend past span for completed tasks only', () {
      final horizon = projectTaskListHorizon(
        project: Project(
          id: '1',
          name: 'P',
          status: 'active',
          startDate: DateTime(2026, 5, 1),
          deadline: DateTime(2026, 5, 31),
        ),
        tasks: [
          Task(
            id: 'a',
            name: 'Done',
            status: 'completed',
            plannedAt: DateTime(2026, 5, 10),
          ),
        ],
      );

      expect(horizon, isNotNull);
      expect(horizon!.localToDay, DateTime(2026, 5, 31));
    });

    test('supports a single-day span', () {
      final horizon = projectTaskListHorizon(
        project: Project(id: '1', name: 'P', status: 'active'),
        tasks: [
          Task(
            id: 'a',
            name: 'One day',
            status: 'completed',
            plannedAt: DateTime(2026, 6, 15),
          ),
        ],
      );

      expect(horizon, isNotNull);
      expect(horizon!.localFromDay, DateTime(2026, 6, 15));
      expect(horizon.localToDay, DateTime(2026, 6, 15));
      expect(horizon.localDays.length, 1);
    });
  });

  group('undatedTasksForProject', () {
    test('returns tasks without planned or deadline dates', () {
      final undated = undatedTasksForProject([
        Task(id: '1', name: 'Dated', status: 'pending', plannedAt: DateTime(2026, 1, 1)),
        Task(id: '2', name: 'Undated', status: 'pending'),
      ]);

      expect(undated, hasLength(1));
      expect(undated.single.name, 'Undated');
    });
  });
}
