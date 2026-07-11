import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/features/productivity/trackers/forms/tracker_form_config.dart';

/// Full-screen single-page form to create a tracker.
class TrackerCreatePage extends StatelessWidget {
  const TrackerCreatePage({super.key, this.goalId});

  final RecordId? goalId;

  static const _trackersQuery = RecordQuery(recordType: 'trackers', limit: 50);

  Future<void> _refreshTrackers(BuildContext context) {
    return refreshRecordQuery(context.read<RecordBloc>(), _trackersQuery);
  }

  @override
  Widget build(BuildContext context) {
    final recordBloc = context.read<RecordBloc>();
    final iconData =
        IconRegistry.instance.getIconData('Chart Line') ?? Icons.show_chart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New tracker'),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(
              alpha: 0.85,
            ),
      ),
      body: AnvilBackgroundIcon(
        icon: iconData,
        opacity: 0.32,
        baseSize: 260,
        child: AnvilForm(
          config: buildTrackerFormConfig(
            recordBloc,
            createOverrides: {
              if (goalId != null) 'goal_id': goalId,
            },
          ),
          submitLabel: 'Create tracker',
          onCancel: () => context.pop(),
          onSubmitSuccess: (_) async {
            await _refreshTrackers(context);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tracker created')),
            );
            context.pop();
          },
        ),
      ),
    );
  }
}
