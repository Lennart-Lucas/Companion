import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/forms/tracker_form_config.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

/// Full-screen form to edit an existing tracker.
class TrackerEditPage extends StatelessWidget {
  const TrackerEditPage({
    super.key,
    required this.trackerId,
    this.tracker,
  });

  final RecordId trackerId;
  final Tracker? tracker;

  static const _trackersQuery = RecordQuery(recordType: 'trackers', limit: 50);

  void _refreshTrackers(BuildContext context) {
    context.read<RecordBloc>().add(const QueryRecordsRequested(_trackersQuery));
  }

  @override
  Widget build(BuildContext context) {
    final recordBloc = context.read<RecordBloc>();
    final iconData =
        IconRegistry.instance.getIconData('Chart Line') ?? Icons.show_chart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit tracker'),
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
            recordId: trackerId,
            preloadedTracker: tracker,
          ),
          submitLabel: 'Save tracker',
          onCancel: () => Navigator.of(context).pop(),
          onSubmitSuccess: (_) {
            _refreshTrackers(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tracker saved')),
            );
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
