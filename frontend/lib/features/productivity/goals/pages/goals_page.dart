import 'package:flutter/material.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/goals/services/goal_list_actions.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_list_tile.dart';
import 'package:frontend/features/productivity/shared/widgets/entity_list_page.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late final GoalListActions _actions = GoalListActions(
    CompanionAnvilApp.instance.apiClient,
  );

  @override
  Widget build(BuildContext context) {
    return EntityListPage<Goal>(
      title: 'Goals',
      iconName: 'Bullseye',
      recordType: 'goals',
      fabTooltip: 'Add goal',
      emptyStateHint: 'Tap + to add a goal',
      buildTile: (context, goal, onTap, onEdit, onDeleted) => GoalListTile(
        goal: goal,
        actions: _actions,
        inGrid: true,
        onTap: onTap,
        onLongPress: onEdit,
        onEdit: onEdit,
        onDeleted: onDeleted,
      ),
    );
  }
}
