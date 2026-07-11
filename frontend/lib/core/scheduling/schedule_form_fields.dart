import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/scheduling/month_day_calendar_field.dart';
import 'package:frontend/features/productivity/scheduling/schedule_picker_field.dart';
import 'package:frontend/features/productivity/tasks/forms/task_planned_deadline_fields.dart';
import 'package:frontend/core/scheduling/schedule_form_values.dart';

typedef ScheduleModeChanged = void Function(AnvilFormBloc bloc, String mode);

class ScheduleFormConfig {
  const ScheduleFormConfig({
    required this.modes,
    required this.subtitle,
    this.repeatingHelperBanner,
    this.oneOffBanner,
    this.startDateLabel = 'Starting from',
    this.endDateLabel = 'Ends on',
    this.showSeriesDates = true,
    this.showTimezone = true,
    this.showExclusions = true,
    this.useAnchorField = false,
    this.companionEndDateFieldKey,
    this.companionEndDateLabel = 'End date',
    this.onModeChanged,
  });

  final List<String> modes;
  final String subtitle;
  final String? repeatingHelperBanner;
  final String? oneOffBanner;
  final String startDateLabel;
  final String endDateLabel;
  final bool showSeriesDates;
  final bool showTimezone;
  final bool showExclusions;
  final bool useAnchorField;
  /// Entity-level end date field (e.g. tracker `end_date`) shown beside anchor.
  final String? companionEndDateFieldKey;
  final String companionEndDateLabel;
  final ScheduleModeChanged? onModeChanged;
}

abstract final class ScheduleFormConfigs {
  static final task = ScheduleFormConfig(
    modes: TaskScheduleMode.all,
    subtitle: 'Choose how this task should occur over time',
    oneOffBanner:
        'The deadline on the previous step is used as the one-off occurrence time.',
    onModeChanged: applyScheduleModeSideEffects,
  );

  static final event = ScheduleFormConfig(
    modes: const [
      TaskScheduleMode.off,
      TaskScheduleMode.repeating,
      TaskScheduleMode.link,
    ],
    subtitle: 'Choose whether this event repeats',
    repeatingHelperBanner:
        'Start and end on the previous step define the time window for each occurrence.',
    startDateLabel: 'Series starts',
    endDateLabel: 'Series ends',
    onModeChanged: applyEventScheduleModeSideEffects,
  );

  static final tracker = ScheduleFormConfig(
    modes: const [TaskScheduleMode.repeating],
    subtitle: 'Recurrence for this tracker',
    showSeriesDates: false,
    showTimezone: false,
    showExclusions: false,
    useAnchorField: true,
    companionEndDateFieldKey: 'end_date',
  );

  static final goal = ScheduleFormConfig(
    modes: const [TaskScheduleMode.repeating],
    subtitle: 'Recurrence for this goal',
    showSeriesDates: false,
    showTimezone: false,
    showExclusions: false,
    useAnchorField: true,
    companionEndDateFieldKey: 'end_date',
  );
}

void applyEventScheduleModeSideEffects(AnvilFormBloc bloc, String mode) {
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
  if (mode == TaskScheduleMode.repeating) {
    ensureScheduleStartDateToday(bloc);
  }
}

/// Unified schedule fields for tasks, events, trackers, and goals.
class ScheduleFormFields extends StatelessWidget {
  const ScheduleFormFields({
    super.key,
    required this.config,
    required this.fieldDecoration,
    this.apiClient,
  });

  final ScheduleFormConfig config;
  final InputDecoration fieldDecoration;
  final ApiClientService? apiClient;

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AnvilFormBloc, String>(
      (bloc) => TaskScheduleFormValues.modeFrom(bloc.state.values),
    );
    final effectiveMode =
        config.modes.length == 1 ? config.modes.first : mode;
    final repeatType = context.select<AnvilFormBloc, String>(
      (bloc) =>
          bloc.state.values[TaskScheduleFormKeys.repeatType]?.toString() ??
          TaskRepeatType.everyNDays,
    );
    final interval = context.select<AnvilFormBloc, int>(
      (bloc) => TaskScheduleFormValues.fromFormMap(bloc.state.values).interval,
    );

    const fieldSpacing = CompanionFormStyles.fieldSpacing;

    final repeatFields = <Widget>[
      if (effectiveMode == TaskScheduleMode.repeating) ...[
        if (config.repeatingHelperBanner != null)
          Padding(
            padding: const EdgeInsets.only(bottom: fieldSpacing),
            child: Text(
              config.repeatingHelperBanner!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (config.showSeriesDates)
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth <
                  CompanionFormStyles.formFieldRowNarrowBreakpoint;
              final startField = AnvilDateField(
                fieldKey: TaskScheduleFormKeys.startDate,
                label: config.startDateLabel,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                decoration: fieldDecoration,
              );
              final endField = AnvilDateField(
                fieldKey: TaskScheduleFormKeys.endDate,
                label: config.endDateLabel,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                decoration: fieldDecoration,
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    startField,
                    const SizedBox(height: fieldSpacing),
                    endField,
                  ],
                );
              }

              return AnvilFormRow(children: [startField, endField]);
            },
          ),
        if (config.useAnchorField)
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth <
                  CompanionFormStyles.formFieldRowNarrowBreakpoint;
              final startField = AnvilDateField(
                fieldKey: TaskScheduleFormKeys.anchor,
                label: 'Start date',
                isRequired: true,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                decoration: fieldDecoration,
              );

              if (config.companionEndDateFieldKey == null) {
                return startField;
              }

              final endField = AnvilDateField(
                fieldKey: config.companionEndDateFieldKey!,
                label: config.companionEndDateLabel,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                decoration: fieldDecoration,
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    startField,
                    const SizedBox(height: fieldSpacing),
                    endField,
                  ],
                );
              }

              return AnvilFormRow(children: [startField, endField]);
            },
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth <
                CompanionFormStyles.formFieldRowNarrowBreakpoint;
            final repeatModeField = AnvilDropdownField<String>(
              fieldKey: TaskScheduleFormKeys.repeatType,
              label: 'Repeat mode',
              isRequired: true,
              options: taskRepeatTypeOptions(),
              decoration: fieldDecoration,
            );
            final intervalEnabled = TaskRepeatType.needsInterval(repeatType);
            final everyDecoration = taskDateFieldDecoration(
              context,
              fieldDecoration,
              enabled: intervalEnabled,
            );
            final everyLabel = intervalEnabled
                ? TaskRepeatType.intervalFieldLabel(
                    repeatType,
                    interval: interval,
                  )
                : 'Every';
            final everyField = wrapDimmedFormField(
              dimmed: !intervalEnabled,
              child: AnvilNumberField(
                fieldKey: TaskScheduleFormKeys.interval,
                label: everyLabel,
                isRequired: intervalEnabled,
                enabled: intervalEnabled,
                min: 1,
                decoration: everyDecoration,
              ),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  repeatModeField,
                  const SizedBox(height: fieldSpacing),
                  everyField,
                ],
              );
            }

            return AnvilFormRow(children: [repeatModeField, everyField]);
          },
        ),
        if (repeatType == TaskRepeatType.weekdays)
          AnvilChipSelectionField<int>(
            fieldKey: TaskScheduleFormKeys.weekdays,
            label: 'On days',
            isRequired: true,
            options: taskWeekdayOptions(),
          ),
        if (repeatType == TaskRepeatType.monthDays)
          if (config.useAnchorField)
            AnvilChipSelectionField<int>(
              fieldKey: TaskScheduleFormKeys.monthDays,
              label: 'Days of month',
              isRequired: true,
              options: taskMonthDayOptions(),
            )
          else
            MonthDayCalendarField(
              fieldKey: TaskScheduleFormKeys.monthDays,
              label: 'Days of month',
              isRequired: true,
            ),
        if (repeatType == TaskRepeatType.specificDates)
          ScheduleDateListField(
            fieldKey: TaskScheduleFormKeys.specificDates,
            label: 'Dates',
            decoration: fieldDecoration,
          ),
        if (config.showTimezone)
          AnvilTextField(
            fieldKey: TaskScheduleFormKeys.timezone,
            label: 'Timezone',
            isRequired: true,
            decoration: fieldDecoration,
          ),
      ],
      if (effectiveMode == TaskScheduleMode.oneOff && config.oneOffBanner != null)
        Padding(
          padding: const EdgeInsets.only(bottom: fieldSpacing),
          child: Text(
            config.oneOffBanner!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      if (effectiveMode == TaskScheduleMode.link && apiClient != null)
        SchedulePickerField(
          apiClient: apiClient!,
          decoration: fieldDecoration,
        ),
      if (config.showExclusions &&
          (effectiveMode == TaskScheduleMode.repeating ||
              effectiveMode == TaskScheduleMode.link)) ...[
        ScheduleDateListField(
          fieldKey: TaskScheduleFormKeys.exclusions,
          label: 'Excluded dates',
          decoration: fieldDecoration,
          emptyLabel: 'No excluded dates',
          addLabel: 'Add exclusion',
        ),
      ],
    ];

    final children = <Widget>[
      if (config.modes.length > 1)
        AnvilSegmentedField<String>(
          fieldKey: TaskScheduleFormKeys.scheduleMode,
          label: 'Schedule mode',
          options: config.modes
              .map(
                (m) => AnvilFieldOption(
                  value: m,
                  label: TaskScheduleMode.labelFor(m),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            final handler = config.onModeChanged;
            if (handler != null) {
              handler(context.read<AnvilFormBloc>(), value);
            }
          },
        ),
      ...repeatFields,
    ];

    return ScheduleTimezoneInitializer(
      child: AnvilFormSection(
        title: 'Schedule',
        subtitle: config.subtitle,
        padding: EdgeInsets.zero,
        showDivider: config.modes.length > 1 ? false : true,
        spacing: CompanionFormStyles.fieldSpacing,
        headerMarginTop: CompanionFormStyles.sectionHeaderMarginTop,
        headerMarginBottom: CompanionFormStyles.sectionHeaderMarginBottom,
        children: children,
      ),
    );
  }
}

class ScheduleDateListField extends StatelessWidget {
  const ScheduleDateListField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.decoration,
    this.emptyLabel = 'No dates added yet',
    this.addLabel = 'Add date',
  });

  final String fieldKey;
  final String label;
  final InputDecoration decoration;
  final String emptyLabel;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dates = context.select<AnvilFormBloc, List<DateTime>>((bloc) {
      return _dateListFromValue(bloc.state.values[fieldKey]);
    });

    return Theme(
      data: theme.copyWith(
        chipTheme: theme.chipTheme.copyWith(
          deleteIconColor: scheme.primary,
          labelStyle: theme.textTheme.bodySmall,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          if (dates.isEmpty)
            Text(
              emptyLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          if (dates.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final date in dates)
                  InputChip(
                    label: Text(_formatDate(date)),
                    onDeleted: () => _removeDate(context, date, dates),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _addDate(context, dates),
            icon: const Icon(Icons.add, size: 18),
            label: Text(addLabel),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _updateDates(BuildContext context, List<DateTime> dates) {
    context.read<AnvilFormBloc>().add(
          AnvilFormFieldUpdated(
            fieldKey,
            dates.map((d) => DateTime(d.year, d.month, d.day)).toList()
              ..sort((a, b) => a.compareTo(b)),
          ),
        );
  }

  Future<void> _addDate(BuildContext context, List<DateTime> current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !context.mounted) return;

    final day = DateTime(picked.year, picked.month, picked.day);
    if (current.any(
      (d) => d.year == day.year && d.month == day.month && d.day == day.day,
    )) {
      return;
    }

    _updateDates(context, [...current, day]);
  }

  void _removeDate(
    BuildContext context,
    DateTime date,
    List<DateTime> current,
  ) {
    _updateDates(
      context,
      current.where((d) => d != date).toList(),
    );
  }

  static List<DateTime> _dateListFromValue(dynamic value) {
    if (value is! List) return [];
    return value
        .map((item) {
          if (item is DateTime) return DateTime(item.year, item.month, item.day);
          if (item is String) return DateTime.tryParse(item);
          return null;
        })
        .whereType<DateTime>()
        .toList();
  }
}

class ScheduleTimezoneInitializer extends StatefulWidget {
  const ScheduleTimezoneInitializer({super.key, required this.child});

  final Widget child;

  @override
  State<ScheduleTimezoneInitializer> createState() =>
      _ScheduleTimezoneInitializerState();
}

class _ScheduleTimezoneInitializerState extends State<ScheduleTimezoneInitializer> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _applyTimezone();
  }

  Future<void> _applyTimezone() async {
    final bloc = context.read<AnvilFormBloc>();
    final current =
        bloc.state.values[TaskScheduleFormKeys.timezone]?.toString().trim();
    if (current != null && current.isNotEmpty) {
      return;
    }

    String tz = 'UTC';
    try {
      tz = await FlutterTimezone.getLocalTimezone();
    } catch (_) {
      tz = 'UTC';
    }

    if (!mounted) return;
    bloc.add(AnvilFormFieldUpdated(TaskScheduleFormKeys.timezone, tz));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Legacy alias.
typedef TaskScheduleTimezoneInitializer = ScheduleTimezoneInitializer;
