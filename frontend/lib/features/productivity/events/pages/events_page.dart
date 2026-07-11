import 'package:flutter/material.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/features/productivity/events/models/event.dart';
import 'package:frontend/features/productivity/events/widgets/event_list_tile.dart';
import 'package:frontend/features/productivity/shared/widgets/record_grid_list_page.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  int _refreshNonce = 0;

  void _refreshList() {
    if (!mounted) return;
    setState(() => _refreshNonce++);
  }

  Future<void> _openCreate() async {
    await CompanionNavigation.openEventCreate(context);
    _refreshList();
  }

  Future<void> _openEdit(BuildContext context, Event event) async {
    await CompanionNavigation.openEventEdit(
      context,
      eventId: event.id,
      event: event,
    );
    _refreshList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add event',
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: RecordGridListPage(
        title: 'Events',
        iconName: 'Calendar',
        recordType: 'events',
        emptyStateHint: 'Tap + to add an event',
        refreshNonce: _refreshNonce,
        itemBuilder: (context, record, index, itemCount) {
          if (record is! Event) {
            return const SizedBox.shrink();
          }
          return EventListTile(
            event: record,
            onTap: () => _openEdit(context, record),
          );
        },
      ),
    );
  }
}
