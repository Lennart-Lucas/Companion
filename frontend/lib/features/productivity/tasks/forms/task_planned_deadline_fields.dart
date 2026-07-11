import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/scheduling/schedule_form_values.dart';

const taskPlannedAtFieldKey = 'planned_at';
const taskDeadlineFieldKey = 'deadline';
const taskStatusFieldKey = 'status';

/// Clears planned/deadline when schedule mode owns task dates.
void clearTaskPlannedAndDeadlineFields(AnvilFormBloc bloc) {
  final values = bloc.state.values;
  if (values[taskPlannedAtFieldKey] != null) {
    bloc.add(const AnvilFormFieldUpdated(taskPlannedAtFieldKey, null));
  }
  if (values[taskDeadlineFieldKey] != null) {
    bloc.add(const AnvilFormFieldUpdated(taskDeadlineFieldKey, null));
  }
}

/// Repeating tasks always use pending status on the template record.
void resetTaskStatusToPending(AnvilFormBloc bloc) {
  if (bloc.state.values[taskStatusFieldKey] == 'pending') return;
  bloc.add(const AnvilFormFieldUpdated(taskStatusFieldKey, 'pending'));
}

/// Clears date fields and resets status when schedule owns dates.
void syncTaskFieldsForRepeat(AnvilFormBloc bloc) {
  clearTaskPlannedAndDeadlineFields(bloc);
  resetTaskStatusToPending(bloc);
}

/// Whether the schedule step controls planned/deadline instead of main fields.
bool scheduleOwnsTaskDates(String mode) =>
    mode == TaskScheduleMode.repeating || mode == TaskScheduleMode.link;

/// Ensures schedule start date is set (defaults to today when enabling repeat).
void ensureScheduleStartDateToday(AnvilFormBloc bloc) {
  if (bloc.state.values[TaskScheduleFormKeys.startDate] != null) return;
  bloc.add(
    AnvilFormFieldUpdated(
      TaskScheduleFormKeys.startDate,
      TaskScheduleFormValues.defaultStartDate(),
    ),
  );
}

/// Applies mutual exclusivity when the user changes schedule mode.
void applyScheduleModeSideEffects(AnvilFormBloc bloc, String mode) {
  if (mode != TaskScheduleMode.link) {
    bloc.add(
      const AnvilFormFieldUpdated(
        TaskScheduleFormKeys.existingScheduleId,
        null,
      ),
    );
  }
  bloc.add(
    AnvilFormFieldUpdated(
      TaskScheduleFormKeys.repeatEnabled,
      mode == TaskScheduleMode.repeating,
    ),
  );
  if (scheduleOwnsTaskDates(mode)) {
    syncTaskFieldsForRepeat(bloc);
  }
  if (mode == TaskScheduleMode.repeating) {
    ensureScheduleStartDateToday(bloc);
  }
}

InputDecoration taskDateFieldDecoration(
  BuildContext context,
  InputDecoration base, {
  required bool enabled,
}) {
  if (enabled) return base;

  final scheme = Theme.of(context).colorScheme;
  final mutedBorder = scheme.onSurface.withValues(alpha: 0.16);

  return base.copyWith(
    filled: true,
    fillColor: scheme.onSurface.withValues(alpha: 0.06),
    enabledBorder: base.enabledBorder?.copyWith(
      borderSide: BorderSide(color: mutedBorder),
    ),
    focusedBorder: base.focusedBorder?.copyWith(
      borderSide: BorderSide(color: mutedBorder),
    ),
  );
}

Widget wrapDimmedFormField({
  required bool dimmed,
  required Widget child,
}) {
  if (!dimmed) return child;
  return Opacity(opacity: 0.45, child: child);
}

Widget wrapDisabledTaskDateField({
  required String scheduleMode,
  required Widget child,
}) {
  return wrapDimmedFormField(
    dimmed: scheduleOwnsTaskDates(scheduleMode),
    child: child,
  );
}

/// Clears planned/deadline whenever schedule owns dates (toggle or hydrate).
class TaskRepeatPlannedDeadlineSync extends StatefulWidget {
  const TaskRepeatPlannedDeadlineSync({super.key, required this.child});

  final Widget child;

  @override
  State<TaskRepeatPlannedDeadlineSync> createState() =>
      _TaskRepeatPlannedDeadlineSyncState();
}

class _TaskRepeatPlannedDeadlineSyncState
    extends State<TaskRepeatPlannedDeadlineSync> {
  String? _previousMode;

  void _syncIfNeeded(String mode) {
    final bloc = context.read<AnvilFormBloc>();
    bloc.add(
      AnvilFormFieldUpdated(
        TaskScheduleFormKeys.repeatEnabled,
        mode == TaskScheduleMode.repeating,
      ),
    );
    if (scheduleOwnsTaskDates(mode)) {
      syncTaskFieldsForRepeat(bloc);
    }
    if (mode == TaskScheduleMode.repeating) {
      ensureScheduleStartDateToday(bloc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AnvilFormBloc, String>(
      (bloc) => TaskScheduleFormValues.modeFrom(bloc.state.values),
    );

    if (_previousMode != mode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncIfNeeded(mode);
        setState(() => _previousMode = mode);
      });
    } else if (_previousMode == null) {
      _previousMode = mode;
      if (scheduleOwnsTaskDates(mode)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncIfNeeded(mode);
        });
      }
    }

    return widget.child;
  }
}
