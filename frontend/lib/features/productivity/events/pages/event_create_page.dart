import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/features/productivity/events/forms/event_form_config.dart';

/// Full-screen wizard to create an event.
class EventCreatePage extends StatelessWidget {
  const EventCreatePage({super.key});

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
        title: const Text('New event'),
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
            apiClient: CompanionAnvilApp.instance.apiClient,
          ),
          onCancel: () => context.pop(),
          onSubmitSuccess: (_) async {
            await _refreshEvents(context);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event created')),
            );
            context.pop();
          },
        ),
      ),
    );
  }
}
