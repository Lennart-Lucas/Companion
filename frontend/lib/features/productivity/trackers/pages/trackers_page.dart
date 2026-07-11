import 'package:flutter/material.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/productivity/shared/widgets/entity_list_page.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_create_page.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_detail_page.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_edit_page.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_tile.dart';

class TrackersPage extends StatefulWidget {
  const TrackersPage({super.key});

  @override
  State<TrackersPage> createState() => _TrackersPageState();
}

class _TrackersPageState extends State<TrackersPage> {
  late final TrackerListActions _actions = TrackerListActions(
    CompanionAnvilApp.instance.apiClient,
  );

  @override
  Widget build(BuildContext context) {
    return EntityListPage<Tracker>(
      title: 'Trackers',
      iconName: 'Chart Line',
      recordType: 'trackers',
      fabTooltip: 'Add tracker',
      emptyStateHint: 'Tap + to add a tracker',
      createPage: const TrackerCreatePage(),
      buildDetailPage: (tracker) =>
          TrackerDetailPage(trackerId: tracker.id, tracker: tracker),
      buildEditPage: (tracker) =>
          TrackerEditPage(trackerId: tracker.id, tracker: tracker),
      buildTile: (context, tracker, onTap, onEdit, onDeleted) =>
          TrackerListTile(
        tracker: tracker,
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
