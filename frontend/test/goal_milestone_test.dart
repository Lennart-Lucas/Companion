import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/goals/models/goal_milestone.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';


void main() {
  group('GoalMilestoneFormValues', () {
    test('toApiPayload skips blank values and assigns sort_order', () {
      final payload = GoalMilestoneFormValues.toApiPayload([
        {'value': '3', 'name': 'Quarter'},
        {'value': '', 'name': 'Skip'},
        {'value': '6'},
      ]);

      expect(payload, [
        {'value': 3, 'name': 'Quarter', 'sort_order': 0},
        {'value': 6, 'sort_order': 1},
      ]);
    });

    test('templatesFromJson parses milestone list', () {
      final milestones = GoalMilestoneFormValues.templatesFromJson([
        {
          'id': 4,
          'value': '6',
          'name': 'Halfway',
          'sort_order': 1,
        },
      ]);

      expect(milestones, hasLength(1));
      expect(milestones.first.id, '4');
      expect(milestones.first.value, 6);
      expect(milestones.first.name, 'Halfway');
      expect(milestones.first.sortOrder, 1);
    });

    test('templatesToFormEntries sorts by sort_order', () {
      final entries = GoalMilestoneFormValues.templatesToFormEntries([
        const GoalMilestone(value: 9, sortOrder: 2),
        const GoalMilestone(value: 3, name: 'Start', sortOrder: 0),
        const GoalMilestone(value: 6, sortOrder: 1),
      ]);

      expect(entries, [
        {'value': 3, 'name': 'Start'},
        {'value': 6},
        {'value': 9},
      ]);
    });
  });

  group('GoalMilestoneValidation', () {
    test('accepts valid increasing milestones', () {
      final error = GoalMilestoneValidation.validateFormValues({
        'goal_type': GoalType.count,
        'target': 12,
        'direction': GoalDirection.increasing,
        GoalMilestoneFormKeys.milestones: [
          {'value': '3'},
          {'value': '6'},
        ],
      });

      expect(error, isNull);
    });

    test('accepts valid decreasing milestones', () {
      final error = GoalMilestoneValidation.validateFormValues({
        'goal_type': GoalType.count,
        'target': 2,
        'direction': GoalDirection.decreasing,
        GoalMilestoneFormKeys.milestones: [
          {'value': '8'},
          {'value': '5'},
        ],
      });

      expect(error, isNull);
    });

    test('skips pulse goals', () {
      final error = GoalMilestoneValidation.validateFormValues({
        'goal_type': GoalType.pulse,
        'target': 10,
        'direction': GoalDirection.decreasing,
        GoalMilestoneFormKeys.milestones: [
          {'value': '20'},
        ],
      });

      expect(error, isNull);
    });

    test('rejects milestone at target for increasing goals', () {
      final error = GoalMilestoneValidation.validateValues(
        target: 12,
        direction: GoalDirection.increasing,
        values: [6, 12],
      );

      expect(error, contains('less than target'));
    });

    test('rejects duplicate values', () {
      final error = GoalMilestoneValidation.validateValues(
        target: 12,
        direction: GoalDirection.increasing,
        values: [3, 3],
      );

      expect(error, contains('unique'));
    });
  });

  group('Goal model milestones', () {
    test('toJson includes milestones on create', () {
      final goal = Goal(
        id: 'temp-1',
        name: 'Books',
        startDate: DateTime.utc(2026, 1, 1),
        target: 12,
        unit: 'books',
        milestones: const [
          GoalMilestone(value: 6, name: 'Halfway'),
        ],
        scheduleCreate: const {'timezone': 'UTC'},
      );

      final json = goal.toJson();
      expect(json['milestones'], [
        {'value': 6, 'name': 'Halfway', 'sort_order': 0},
      ]);
    });

    test('fromJson parses milestones and milestoneCount getter works', () {
      final goal = Goal.fromJson({
        'id': 1,
        'name': 'Books',
        'start_date': '2026-01-01T00:00:00Z',
        'goal_type': 'count',
        'target': 12,
        'unit': 'books',
        'direction': 'increasing',
        'milestones': [
          {'id': 1, 'value': 3, 'sort_order': 0},
          {'id': 2, 'value': 6, 'sort_order': 1},
        ],
      });

      expect(goal.milestoneCount, 2);
      expect(goal.milestones.first.value, 3);
    });
  });
}
