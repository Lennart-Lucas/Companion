import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/widgets/goal_list_tile.dart';

void main() {
  setUp(setupCompanionIcons);

  testWidgets('GoalListTile shows name and count target summary', (
    WidgetTester tester,
  ) async {
    final goal = Goal(
      id: '1',
      name: 'Read 12 books',
      goalType: GoalType.count,
      target: 12,
      unit: 'books',
      direction: GoalDirection.increasing,
      startDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2026, 12, 31),
      color: '#3366FF',
      icon: 'Bullseye',
      milestoneCount: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalListTile(goal: goal),
        ),
      ),
    );

    expect(find.text('Read 12 books'), findsOneWidget);
    expect(
      find.text(
        'Count · 12 books · Increasing · 2 milestones · 2026-01-01 – 2026-12-31',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GoalListTile shows task type', (
    WidgetTester tester,
  ) async {
    final goal = Goal(
      id: '2',
      name: 'Weekly workouts',
      goalType: GoalType.task,
      target: 4,
      unit: 'sessions',
      direction: GoalDirection.increasing,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalListTile(goal: goal),
        ),
      ),
    );

    expect(find.text('Weekly workouts'), findsOneWidget);
    expect(find.textContaining('Task'), findsOneWidget);
    expect(find.textContaining('4 sessions'), findsOneWidget);
  });

  testWidgets('GoalListTile shows decreasing direction', (
    WidgetTester tester,
  ) async {
    final goal = Goal(
      id: '3',
      name: 'Reduce screen time',
      goalType: GoalType.pulse,
      target: 2,
      unit: 'hours',
      direction: GoalDirection.decreasing,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalListTile(goal: goal),
        ),
      ),
    );

    expect(find.text('Reduce screen time'), findsOneWidget);
    expect(find.textContaining('Pulse'), findsOneWidget);
    expect(find.textContaining('Decreasing'), findsOneWidget);
  });
}
