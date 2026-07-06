import 'package:flutter/material.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/pages/tracker_create_page.dart';
import 'package:frontend/features/productivity/pages/tracker_detail_page.dart';
import 'package:frontend/features/productivity/pages/tracker_edit_page.dart';
import 'package:frontend/features/productivity/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/widgets/productivity_list_page.dart';
import 'package:frontend/features/productivity/widgets/tracker_list_tile.dart';

class TrackersPage extends StatefulWidget {
  const TrackersPage({super.key});

  @override
  State<TrackersPage> createState() => _TrackersPageState();
}

class _TrackersPageState extends State<TrackersPage> {
  int _refreshNonce = 0;

  late final TrackerListActions _actions = TrackerListActions(
    CompanionAnvilApp.instance.apiClient,
  );

  void _refreshList() {
    if (!mounted) return;
    setState(() => _refreshNonce++);
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TrackerCreatePage(),
      ),
    );
    _refreshList();
  }

  void _openDetail(BuildContext context, Tracker tracker) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TrackerDetailPage(
              trackerId: tracker.id,
              tracker: tracker,
            ),
          ),
        )
        .then((_) => _refreshList());
  }

  void _openEdit(BuildContext context, Tracker tracker) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TrackerEditPage(
              trackerId: tracker.id,
              tracker: tracker,
            ),
          ),
        )
        .then((_) => _refreshList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-trackers',
        tooltip: 'Add tracker',
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: ProductivityListPage(
        title: 'Trackers',
        iconName: 'Chart Line',
        recordType: 'trackers',
        emptyStateHint: 'Tap + to add a tracker',
        refreshNonce: _refreshNonce,
        showDividers: false,
        itemBuilder: (context, record, index, itemCount) {
          if (record is! Tracker) {
            return const SizedBox.shrink();
          }
          return TrackerListTile(
            tracker: record,
            actions: _actions,
            onTap: () => _openDetail(context, record),
            onLongPress: () => _openEdit(context, record),
            onEdit: () => _openEdit(context, record),
            onDeleted: _refreshList,
          );
        },
      ),
    );
  }
}
