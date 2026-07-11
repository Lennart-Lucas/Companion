import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/core/records/record_json_utils.dart';
import 'package:frontend/core/records/record_form_utils.dart';
import 'package:frontend/core/scheduling/schedule_form_values.dart';

abstract final class TrackerCheckInType {
  static const task = 'task';
  static const count = 'count';
  static const duration = 'duration';
}

abstract final class TrackerHabitDirection {
  static const build = 'build';
  static const quit = 'quit';
}

class Tracker extends ProductivityRecord {
  @override
  final RecordId id;
  @override
  RecordType get recordType => 'trackers';
  @override
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final String? goalId;
  final String? scheduleId;
  final DateTime startDate;
  final DateTime? endDate;
  final String checkInType;
  final num? target;
  final String? unit;
  final String habitDirection;
  final Map<String, dynamic>? scheduleCreate;

  Tracker({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    this.goalId,
    this.scheduleId,
    required this.startDate,
    this.endDate,
    this.checkInType = TrackerCheckInType.task,
    this.target,
    this.unit,
    this.habitDirection = TrackerHabitDirection.build,
    this.scheduleCreate,
  });

  factory Tracker.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    final startDate = RecordJsonUtils.dateTimeFromJson(data['start_date']);
    final parsedStart = startDate ?? DateTime.now();
    final localStart = parsedStart.toLocal();
    return Tracker(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      color: data['color'] as String?,
      goalId: RecordJsonUtils.parentIdFromJson(data['goal_id']),
      scheduleId: RecordJsonUtils.parentIdFromJson(data['schedule_id']),
      startDate: DateTime(
        localStart.year,
        localStart.month,
        localStart.day,
      ),
      endDate: RecordJsonUtils.dateTimeFromJson(data['end_date']),
      checkInType:
          data['check_in_type'] as String? ?? TrackerCheckInType.task,
      target: RecordJsonUtils.optionalTargetFromJson(data['target']),
      unit: data['unit'] as String?,
      habitDirection:
          data['habit_direction'] as String? ?? TrackerHabitDirection.build,
    );
  }

  static DateTime _startDateFromFormValues(Map<String, dynamic> values) {
    final schedule = TaskScheduleFormValues.fromFormMap({
      ...values,
      TaskScheduleFormKeys.repeatEnabled: true,
    });
    final anchor = schedule.resolvedAnchorFromAnchorField();
    if (anchor != null) {
      return DateTime(anchor.year, anchor.month, anchor.day);
    }
    return TaskScheduleFormValues.defaultStartDate();
  }

  factory Tracker.fromFormValues(
    Map<String, dynamic> values, {
    String? id,
  }) {
    final name = (values['name'] as String? ?? '').trim();
    final resolvedId = id ?? 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final schedule = TaskScheduleFormValues.fromFormMap({
      ...values,
      TaskScheduleFormKeys.repeatEnabled: true,
    });
    final checkInType =
        values['check_in_type'] as String? ?? TrackerCheckInType.task;

    return Tracker(
      id: resolvedId,
      name: name,
      description: (values['description'] as String?)?.trim(),
      icon: RecordFormUtils.iconFromFormValue(values['icon']),
      color: RecordFormUtils.colorHexFromFormValue(values['color']),
      goalId: RecordJsonUtils.parentIdFromFormValue(values['goal_id']),
      scheduleId: RecordJsonUtils.parentIdFromFormValue(
        values['existing_schedule_id'],
      ),
      startDate: _startDateFromFormValues(values),
      endDate: values['end_date'] as DateTime?,
      checkInType: checkInType,
      target: RecordJsonUtils.optionalTargetFromFormValue(values['target']),
      unit: (values['unit'] as String?)?.trim(),
      habitDirection:
          values['habit_direction'] as String? ?? TrackerHabitDirection.build,
      scheduleCreate: schedule.toScheduleCreateJson(preferAnchorField: true),
    );
  }

  Map<String, dynamic> toFormValues() => {
        'name': name,
        'description': description ?? '',
        'icon': icon,
        'color': RecordFormUtils.colorFormValueFromHex(color),
        'goal_id': goalId ?? '',
        'end_date': endDate,
        'check_in_type': checkInType,
        'target': target,
        'unit': unit ?? '',
        'habit_direction': habitDirection,
        TaskScheduleFormKeys.anchor:
            DateTime(startDate.year, startDate.month, startDate.day),
        if (scheduleId != null) 'existing_schedule_id': scheduleId,
      };

  bool get _isTempId => RecordJsonUtils.isTempId(id);

  @override
  Map<String, dynamic> toJson() {
    final scheduleTimezone =
        scheduleCreate?['timezone']?.toString() ?? 'UTC';
    final map = <String, dynamic>{
      'name': name,
      'start_date': TaskScheduleFormValues.dtstartAtScheduleMidnight(
        DateTime(startDate.year, startDate.month, startDate.day),
        scheduleTimezone,
      ).toIso8601String(),
      'check_in_type': checkInType,
      'habit_direction': habitDirection,
    };
    if (!_isTempId) {
      map['id'] = id;
    }
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      map['description'] = desc;
    }
    if (endDate != null) {
      map['end_date'] = endDate!.toUtc().toIso8601String();
    }
    if (goalId != null && goalId!.isNotEmpty) {
      map['goal_id'] = int.parse(goalId!);
    }
    final iconName = icon?.trim();
    if (iconName != null && iconName.isNotEmpty) {
      map['icon'] = iconName;
    }
    final colorHex = color?.trim();
    if (colorHex != null && colorHex.isNotEmpty) {
      map['color'] = colorHex;
    }

    if (checkInType == TrackerCheckInType.count) {
      if (target != null) {
        map['target'] = target;
      }
      final unitValue = unit?.trim();
      if (unitValue != null && unitValue.isNotEmpty) {
        map['unit'] = unitValue;
      }
    } else if (checkInType == TrackerCheckInType.duration) {
      if (target != null) {
        map['target'] = target;
      }
    }

    if (scheduleCreate != null) {
      map['schedule'] = scheduleCreate;
    }

    return map;
  }

  Map<String, dynamic> toFormValuesWithSchedule(
    TaskScheduleFormValues schedule,
  ) =>
      {
        ...toFormValues(),
        ...schedule.toFormMap(),
        TaskScheduleFormKeys.repeatEnabled: true,
        if (scheduleId != null) 'existing_schedule_id': scheduleId,
      };
}
