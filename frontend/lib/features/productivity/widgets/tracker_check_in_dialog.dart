import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/duration_hms_input_field.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/widgets/project_display.dart';

Future<bool?> showTrackerCheckInDialog({
  required BuildContext context,
  required Tracker tracker,
  required TrackerCheckInRepository repository,
  TrackerCheckIn? checkIn,
  required DateTime checkInAt,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => TrackerCheckInDialog(
      tracker: tracker,
      repository: repository,
      checkIn: checkIn,
      checkInAt: checkInAt,
    ),
  );
}

class TrackerCheckInDialog extends StatefulWidget {
  const TrackerCheckInDialog({
    super.key,
    required this.tracker,
    required this.repository,
    required this.checkInAt,
    this.checkIn,
  });

  final Tracker tracker;
  final TrackerCheckInRepository repository;
  final TrackerCheckIn? checkIn;
  final DateTime checkInAt;

  @override
  State<TrackerCheckInDialog> createState() => _TrackerCheckInDialogState();
}

class _TrackerCheckInDialogState extends State<TrackerCheckInDialog> {
  late bool _completed;
  late TextEditingController _countController;
  final _durationFieldKey = GlobalKey<DurationHmsInputFieldState>();
  late int _durationSeconds;
  bool _skipped = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.checkIn != null;

  @override
  void initState() {
    super.initState();
    final checkIn = widget.checkIn;
    _completed = checkIn?.completed ?? false;
    _skipped = checkIn?.skipped ?? false;
    _countController = TextEditingController(
      text: checkIn?.countValue?.toString() ?? '',
    );
    _durationSeconds = checkIn == null
        ? 0
        : trackerCheckInElapsedSeconds(checkIn, DateTime.now());
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  int _readDurationSeconds() {
    return _durationFieldKey.currentState?.readTotalSeconds() ?? _durationSeconds;
  }

  String _formatCheckInAt() {
    final local = widget.checkInAt.toLocal();
    final date = formatProjectDate(local);
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final type = widget.tracker.checkInType;
      if (_isEdit) {
        await widget.repository.updateCheckIn(
          widget.tracker.id,
          widget.checkIn!.id,
          checkInType: type,
          completed: type == TrackerCheckInType.task ? _completed : null,
          countValue: type == TrackerCheckInType.count
              ? num.tryParse(_countController.text.trim())
              : null,
          valueSeconds: type == TrackerCheckInType.duration
              ? _readDurationSeconds()
              : null,
          skipped: _skipped,
        );
      } else {
        await widget.repository.createCheckIn(
          widget.tracker.id,
          checkInAt: widget.checkInAt,
          checkInType: type,
          completed: type == TrackerCheckInType.task ? _completed : null,
          countValue: type == TrackerCheckInType.count
              ? num.tryParse(_countController.text.trim())
              : null,
          valueSeconds: type == TrackerCheckInType.duration
              ? _readDurationSeconds()
              : null,
          skipped: _skipped,
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

  Widget _buildFields() {
    if (_skipped) {
      return Text(
        'This check-in will be marked as skipped.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return switch (widget.tracker.checkInType) {
      TrackerCheckInType.task => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Completed'),
          value: _completed,
          onChanged: _saving
              ? null
              : (value) => setState(() => _completed = value),
        ),
      TrackerCheckInType.count => TextField(
          controller: _countController,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.tracker.unit?.trim().isNotEmpty == true
                ? 'Count (${widget.tracker.unit})'
                : 'Count',
          ),
        ),
      TrackerCheckInType.duration => DurationHmsInputField(
          key: _durationFieldKey,
          initialSeconds: _durationSeconds,
          enabled: !_saving,
          onChanged: (seconds) => _durationSeconds = seconds,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit check-in' : 'Log check-in';

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _formatCheckInAt(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 12),
            _buildFields(),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Skipped'),
              value: _skipped,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _skipped = value ?? false),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
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
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Save' : 'Log'),
        ),
      ],
    );
  }
}

Future<TrackerCheckIn?> showTrackerCheckInMomentPicker({
  required BuildContext context,
  required List<TrackerCheckIn> checkIns,
}) {
  return showModalBottomSheet<TrackerCheckIn>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Choose check-in',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final checkIn in checkIns)
            ListTile(
              title: Text(_formatMoment(checkIn.checkInAt)),
              subtitle: Text(checkIn.logged ? 'Logged' : 'Not logged'),
              onTap: () => Navigator.of(context).pop(checkIn),
            ),
        ],
      ),
    ),
  );
}

String _formatMoment(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatProjectDate(local)} $hour:$minute';
}
