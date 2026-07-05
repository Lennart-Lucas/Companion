import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/scheduling/task_occurrence_api.dart';
import 'package:frontend/features/productivity/forms/task_field_option_tile.dart';
import 'package:frontend/features/productivity/models/task_occurrence.dart';

/// Lazy occurrence list for a recurring task on the edit screen.
class TaskOccurrencesSection extends StatefulWidget {
  const TaskOccurrencesSection({
    super.key,
    required this.taskId,
    required this.apiClient,
  });

  final RecordId taskId;
  final ApiClientService apiClient;

  @override
  State<TaskOccurrencesSection> createState() => _TaskOccurrencesSectionState();
}

class _TaskOccurrencesSectionState extends State<TaskOccurrencesSection> {
  late final TaskOccurrenceApi _api = TaskOccurrenceApi(widget.apiClient);

  List<TaskOccurrence> _occurrences = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = DateTime.now().subtract(const Duration(days: 7));
      final to = DateTime.now().add(const Duration(days: 90));
      final items = await _api.listOccurrences(
        widget.taskId,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _occurrences = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _patchStatus(TaskOccurrence occurrence, String status) async {
    try {
      final updated = await _api.patchOccurrence(
        widget.taskId,
        occurrence.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _occurrences = [
          for (final item in _occurrences)
            if (item.id == updated.id) updated else item,
        ];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _toggleSubtask(
    TaskOccurrence occurrence,
    TaskOccurrenceSubtask subtask,
    bool completed,
  ) async {
    try {
      await _api.patchOccurrenceSubtask(
        widget.taskId,
        occurrence.id,
        subtask.id,
        completed: completed,
      );
      if (!mounted) return;
      setState(() {
        _occurrences = [
          for (final item in _occurrences)
            if (item.id != occurrence.id)
              item
            else
              TaskOccurrence(
                id: item.id,
                occurrenceAt: item.occurrenceAt,
                status: item.status,
                priority: item.priority,
                subtasks: [
                  for (final st in item.subtasks)
                    if (st.id == subtask.id)
                      TaskOccurrenceSubtask(
                        id: st.id,
                        title: st.title,
                        completed: completed,
                      )
                    else
                      st,
                ],
              ),
        ];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Occurrences',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              )
            else if (_occurrences.isEmpty)
              Text(
                'No occurrences in the next 90 days.',
                style: theme.textTheme.bodySmall,
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _occurrences.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final occurrence = _occurrences[index];
                    return _OccurrenceTile(
                      occurrence: occurrence,
                      onStatusSelected: (status) =>
                          _patchStatus(occurrence, status),
                      onSubtaskToggled: (subtask, completed) =>
                          _toggleSubtask(occurrence, subtask, completed),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  const _OccurrenceTile({
    required this.occurrence,
    required this.onStatusSelected,
    required this.onSubtaskToggled,
  });

  final TaskOccurrence occurrence;
  final ValueChanged<String> onStatusSelected;
  final void Function(TaskOccurrenceSubtask subtask, bool completed)
      onSubtaskToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final when = occurrence.occurrenceAt.toLocal();
    final label =
        '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')} '
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(label, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        occurrence.status,
        style: theme.textTheme.bodySmall?.copyWith(
          color: taskStatusColor(occurrence.status, scheme),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final status in const ['pending', 'in_progress', 'completed'])
                ActionChip(
                  label: Text(status),
                  onPressed: occurrence.status == status
                      ? null
                      : () => onStatusSelected(status),
                ),
            ],
          ),
        ),
        for (final subtask in occurrence.subtasks)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(subtask.title),
            value: subtask.completed,
            onChanged: (value) => onSubtaskToggled(subtask, value == true),
          ),
      ],
    );
  }
}
