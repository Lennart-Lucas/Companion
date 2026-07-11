import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/core/records/record_json_utils.dart';
import 'package:frontend/core/records/record_form_utils.dart';
import 'package:frontend/core/scheduling/schedule_form_values.dart';
import 'package:frontend/features/productivity/goals/models/goal_milestone.dart';

abstract final class GoalType {
  static const count = 'count';
  static const task = 'task';
  static const pulse = 'pulse';
}

abstract final class GoalDirection {
  static const increasing = 'increasing';
  static const decreasing = 'decreasing';
}

class Goal extends ProductivityRecord {
  @override
  final RecordId id;
  @override
  RecordType get recordType => 'goals';
  @override
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final String? scheduleId;
  final DateTime startDate;
  final DateTime? endDate;
  final String goalType;
  final num target;
  final String unit;
  final String direction;
  final List<GoalMilestone>? _milestones;
  final Map<String, dynamic>? scheduleCreate;

  List<GoalMilestone> get milestones => _milestones ?? const [];

  int get milestoneCount => milestones.length;

  Goal({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    this.scheduleId,
    required this.startDate,
    this.endDate,
    this.goalType = GoalType.count,
    required this.target,
    required this.unit,
    this.direction = GoalDirection.increasing,
    List<GoalMilestone>? milestones,
    this.scheduleCreate,
  }) : _milestones = milestones;

  static List<GoalMilestone> _milestonesFromJson(dynamic value) =>
      GoalMilestoneFormValues.templatesFromJson(value);

  factory Goal.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    final startDate = RecordJsonUtils.dateTimeFromJson(data['start_date']);
    return Goal(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      color: data['color'] as String?,
      scheduleId: RecordJsonUtils.parentIdFromJson(data['schedule_id']),
      startDate: startDate ?? DateTime.now(),
      endDate: RecordJsonUtils.dateTimeFromJson(data['end_date']),
      goalType: data['goal_type'] as String? ?? GoalType.count,
      target: RecordJsonUtils.targetFromJson(data['target']),
      unit: data['unit'] as String? ?? '',
      direction: data['direction'] as String? ?? GoalDirection.increasing,
      milestones: _milestonesFromJson(data['milestones']),
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

  factory Goal.fromFormValues(
    Map<String, dynamic> values, {
    String? id,
  }) {
    final name = (values['name'] as String? ?? '').trim();
    final resolvedId = id ?? 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final schedule = TaskScheduleFormValues.fromFormMap({
      ...values,
      TaskScheduleFormKeys.repeatEnabled: true,
    });

    final milestonesPayload = GoalMilestoneFormValues.toApiPayload(
      values[GoalMilestoneFormKeys.milestones],
    );

    return Goal(
      id: resolvedId,
      name: name,
      description: (values['description'] as String?)?.trim(),
      icon: RecordFormUtils.iconFromFormValue(values['icon']),
      color: RecordFormUtils.colorHexFromFormValue(values['color']),
      scheduleId:
          RecordJsonUtils.parentIdFromFormValue(values['existing_schedule_id']),
      startDate: _startDateFromFormValues(values),
      endDate: values['end_date'] as DateTime?,
      goalType: values['goal_type'] as String? ?? GoalType.count,
      target: RecordJsonUtils.targetFromFormValue(values['target']),
      unit: (values['unit'] as String? ?? '').trim(),
      direction: values['direction'] as String? ?? GoalDirection.increasing,
      milestones: [
        for (final row in milestonesPayload)
          GoalMilestone(
            value: row['value'] as num,
            name: row['name'] as String?,
            sortOrder: row['sort_order'] as int,
          ),
      ],
      scheduleCreate: schedule.toScheduleCreateJson(preferAnchorField: true),
    );
  }

  Map<String, dynamic> toFormValues() => {
        'name': name,
        'description': description ?? '',
        'icon': icon,
        'color': RecordFormUtils.colorFormValueFromHex(color),
        'end_date': endDate,
        'goal_type': goalType,
        'target': target,
        'unit': unit,
        'direction': direction,
        GoalMilestoneFormKeys.milestones:
            GoalMilestoneFormValues.templatesToFormEntries(milestones),
        TaskScheduleFormKeys.anchor:
            DateTime(startDate.year, startDate.month, startDate.day),
        if (scheduleId != null) 'existing_schedule_id': scheduleId,
      };

  bool get _isTempId => RecordJsonUtils.isTempId(id);

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'start_date': startDate.toUtc().toIso8601String(),
      'goal_type': goalType,
      'target': target,
      'unit': unit,
      'direction': direction,
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
    final iconName = icon?.trim();
    if (iconName != null && iconName.isNotEmpty) {
      map['icon'] = iconName;
    }
    final colorHex = color?.trim();
    if (colorHex != null && colorHex.isNotEmpty) {
      map['color'] = colorHex;
    }
    if (scheduleCreate != null) {
      map['schedule'] = scheduleCreate;
    }
    if (_isTempId && milestones.isNotEmpty) {
      map['milestones'] = [
        for (var i = 0; i < milestones.length; i++)
          milestones[i].toApiJson(i),
      ];
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
