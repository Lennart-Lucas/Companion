import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/features/productivity/events/forms/event_form_config.dart';
import 'package:frontend/features/productivity/events/models/event.dart';


/// Full-screen wizard to edit an existing event.
class EventEditPage extends StatelessWidget {
  const EventEditPage({
    super.key,
    required this.eventId,
    this.event,
    this.apiClient,
  });

  final RecordId eventId;
  final Event? event;
  final ApiClientService? apiClient;

  ApiClientService _resolveApiClient() =>
      apiClient ?? CompanionAnvilApp.instance.apiClient;

  static const _eventsQuery = RecordQuery(recordType: 'events', limit: 50);

  Future<void> _refreshEvents(BuildContext context) {
    return refreshRecordQuery(context.read<RecordBloc>(), _eventsQuery);
  }

  @override
  Widget build(BuildContext context) {
    final recordBloc = context.read<RecordBloc>();
    final iconData =
        IconRegistry.instance.getIconData('Calendar') ??
            Icons.calendar_today_outlined;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit event'),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(
              alpha: 0.85,
            ),
      ),
      body: AnvilBackgroundIcon(
        icon: iconData,
        opacity: 0.32,
        baseSize: 260,
        child: AnvilFormWizard(
          config: buildEventFormConfig(
            recordBloc,
            apiClient: _resolveApiClient(),
            recordId: eventId,
            preloadedEvent: event,
          ),
          onCancel: () => context.pop(),
          onSubmitSuccess: (_) async {
            await _refreshEvents(context);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event saved')),
            );
            context.pop();
          },
        ),
      ),
    );
  }
}
