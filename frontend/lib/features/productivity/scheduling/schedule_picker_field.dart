import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/scheduling/schedule_api.dart';
import 'package:frontend/features/productivity/models/task_schedule.dart';

/// Picks an existing schedule from `GET /schedules`.
class SchedulePickerField extends StatefulWidget {
  const SchedulePickerField({
    super.key,
    required this.apiClient,
    required this.decoration,
  });

  final ApiClientService apiClient;
  final InputDecoration decoration;

  @override
  State<SchedulePickerField> createState() => _SchedulePickerFieldState();
}

class _SchedulePickerFieldState extends State<SchedulePickerField> {
  late final ScheduleApi _scheduleApi = ScheduleApi(widget.apiClient);
  List<Map<String, dynamic>> _schedules = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final items = await _scheduleApi.listSchedules();
      if (!mounted) return;
      setState(() {
        _schedules = items;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadSchedules();
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_schedules.isEmpty) {
      return Text(
        'No schedules available yet. Create a repeating task first.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final options = _schedules
        .map((schedule) {
          final id = schedule['id']?.toString() ?? '';
          if (id.isEmpty) return null;
          return AnvilFieldOption<String>(
            value: id,
            label: scheduleSummaryLabel(schedule),
          );
        })
        .whereType<AnvilFieldOption<String>>()
        .toList();

    return AnvilDropdownField<String>(
      fieldKey: TaskScheduleFormKeys.existingScheduleId,
      label: 'Schedule',
      isRequired: true,
      options: options,
      decoration: widget.decoration,
    );
  }
}
