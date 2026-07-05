import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/forms/goal_form_config.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

/// Full-screen form to edit an existing goal.
class GoalEditPage extends StatelessWidget {
  const GoalEditPage({
    super.key,
    required this.goalId,
    this.goal,
  });

  final RecordId goalId;
  final Goal? goal;

  static const _goalsQuery = RecordQuery(recordType: 'goals', limit: 50);

  void _refreshGoals(BuildContext context) {
    context.read<RecordBloc>().add(const QueryRecordsRequested(_goalsQuery));
  }

  @override
  Widget build(BuildContext context) {
    final recordBloc = context.read<RecordBloc>();
    final iconData =
        IconRegistry.instance.getIconData('Bullseye') ?? Icons.flag_outlined;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit goal'),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(
              alpha: 0.85,
            ),
      ),
      body: AnvilBackgroundIcon(
        icon: iconData,
        opacity: 0.32,
        baseSize: 260,
        child: AnvilForm(
          config: buildGoalFormConfig(
            recordBloc,
            recordId: goalId,
            preloadedGoal: goal,
          ),
          submitLabel: 'Save goal',
          onCancel: () => Navigator.of(context).pop(),
          onSubmitSuccess: (_) {
            _refreshGoals(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Goal saved')),
            );
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
