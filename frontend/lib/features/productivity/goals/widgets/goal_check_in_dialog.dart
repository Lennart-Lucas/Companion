import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';

Future<bool?> showGoalCheckInDialog({
  required BuildContext context,
  required Goal goal,
  required GoalCheckInRepository repository,
  GoalCheckIn? checkIn,
  required DateTime checkInAt,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => GoalCheckInDialog(
      goal: goal,
      repository: repository,
      checkIn: checkIn,
      checkInAt: checkInAt,
    ),
  );
}

class GoalCheckInDialog extends StatefulWidget {
  const GoalCheckInDialog({
    super.key,
    required this.goal,
    required this.repository,
    required this.checkInAt,
    this.checkIn,
  });

  final Goal goal;
  final GoalCheckInRepository repository;
  final GoalCheckIn? checkIn;
  final DateTime checkInAt;

  @override
  State<GoalCheckInDialog> createState() => _GoalCheckInDialogState();
}

class _GoalCheckInDialogState extends State<GoalCheckInDialog> {
  late bool _completed;
  late TextEditingController _countController;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.checkIn != null;
  bool get _isPulse => widget.goal.goalType == GoalType.pulse;

  @override
  void initState() {
    super.initState();
    final checkIn = widget.checkIn;
    _completed = checkIn?.completed ?? false;
    _countController = TextEditingController(
      text: checkIn?.countValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  String _formatCheckInAt() {
    final local = widget.checkInAt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (_isPulse) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (widget.checkIn == null) {
        throw StateError('Check-in must exist before logging');
      }

      if (widget.goal.goalType == GoalType.task) {
        await widget.repository.updateCheckIn(
          widget.goal.id,
          widget.checkIn!.id,
          completed: _completed,
        );
      } else if (widget.goal.goalType == GoalType.count) {
        final raw = _countController.text.trim();
        final value = num.tryParse(raw);
        if (value == null) {
          throw FormatException('Enter a valid count');
        }
        await widget.repository.updateCheckIn(
          widget.goal.id,
          widget.checkIn!.id,
          countValue: value,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEdit ? 'Edit check-in' : 'Log check-in'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.goal.name,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              _formatCheckInAt(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            if (_isPulse) ...[
              Text(
                widget.checkIn?.pulseScore != null
                    ? 'Pulse score: ${widget.checkIn!.pulseScore}/10'
                    : 'Pulse scores are system-generated.',
                style: theme.textTheme.bodyMedium,
              ),
            ] else if (widget.goal.goalType == GoalType.task) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Completed'),
                value: _completed,
                onChanged: _saving ? null : (value) => setState(() => _completed = value),
              ),
            ] else if (widget.goal.goalType == GoalType.count) ...[
              TextField(
                controller: _countController,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Count (${widget.goal.unit.trim()})',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (!_isPulse)
          FilledButton(
            onPressed: _saving || widget.checkIn == null ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
      ],
    );
  }
}
