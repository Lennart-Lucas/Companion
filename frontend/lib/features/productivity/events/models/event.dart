import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/core/records/record_json_utils.dart';
import 'package:frontend/core/records/record_form_utils.dart';
import 'package:frontend/core/scheduling/schedule_form_values.dart';

class Event extends ProductivityRecord {
  @override
  final RecordId id;
  @override
  RecordType get recordType => 'events';
  @override
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final DateTime startAt;
  final DateTime? endAt;
  final String? scheduleId;
  final bool isRecurring;
  final Map<String, dynamic>? scheduleCreate;
  final bool clearSchedule;
  final bool attachScheduleId;

  Event({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    required this.startAt,
    this.endAt,
    this.scheduleId,
    this.isRecurring = false,
    this.scheduleCreate,
    this.clearSchedule = false,
    this.attachScheduleId = false,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    final startAt = RecordJsonUtils.dateTimeFromJson(data['start_at']);
    return Event(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      color: data['color'] as String?,
      startAt: startAt ?? DateTime.now(),
      endAt: RecordJsonUtils.dateTimeFromJson(data['end_at']),
      scheduleId: RecordJsonUtils.parentIdFromFormValue(data['schedule_id']),
      isRecurring: data['is_recurring'] == true,
    );
  }

  factory Event.fromFormValues(
    Map<String, dynamic> values, {
    String? id,
  }) {
    final name = (values['name'] as String? ?? '').trim();
    final resolvedId = id ?? 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final schedule = TaskScheduleFormValues.fromFormMap(values);
    final existingScheduleId = schedule.existingScheduleId ??
        RecordJsonUtils.parentIdFromFormValue(
          values[TaskScheduleFormKeys.existingScheduleId],
        );
    final originalScheduleId = RecordJsonUtils.parentIdFromFormValue(
      values[TaskScheduleFormKeys.originalScheduleId],
    );
    final isUpdate = !resolvedId.startsWith('temp-');
    final startAt = values['start_at'] as DateTime?;

    Map<String, dynamic>? scheduleCreate;
    bool clearSchedule = false;
    bool attachScheduleId = false;
    String? scheduleId;

    switch (schedule.mode) {
      case TaskScheduleMode.off:
        if (isUpdate && (originalScheduleId ?? existingScheduleId) != null) {
          clearSchedule = true;
        }
      case TaskScheduleMode.oneOff:
        break;
      case TaskScheduleMode.repeating:
        scheduleCreate = _eventScheduleCreateJson(
          schedule: schedule,
          startAt: startAt,
        );
        scheduleId = null;
      case TaskScheduleMode.link:
        scheduleId = existingScheduleId;
        attachScheduleId = !isUpdate && scheduleId != null;
    }

    return Event(
      id: resolvedId,
      name: name,
      description: (values['description'] as String?)?.trim(),
      icon: RecordFormUtils.iconFromFormValue(values['icon']),
      color: RecordFormUtils.colorHexFromFormValue(values['color']),
      startAt: startAt ?? DateTime.now(),
      endAt: values['end_at'] as DateTime?,
      scheduleId: scheduleId,
      isRecurring: schedule.mode == TaskScheduleMode.repeating,
      scheduleCreate: scheduleCreate,
      clearSchedule: clearSchedule,
      attachScheduleId: attachScheduleId,
    );
  }

  Map<String, dynamic> toFormValues() => {
        'name': name,
        'description': description ?? '',
        'start_at': startAt,
        'end_at': endAt,
        'icon': icon,
        'color': RecordFormUtils.colorFormValueFromHex(color),
        if (scheduleId != null)
          TaskScheduleFormKeys.existingScheduleId: scheduleId,
      };

  bool get _isTempId => RecordJsonUtils.isTempId(id);

  static Map<String, dynamic>? _eventScheduleCreateJson({
    required TaskScheduleFormValues schedule,
    DateTime? startAt,
  }) {
    final json = schedule.toScheduleCreateJson(fallbackAnchor: startAt);
    if (json == null) return null;
    if (startAt != null) {
      json['dtstart'] = startAt.toUtc().toIso8601String();
    }
    return json;
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'start_at': startAt.toUtc().toIso8601String(),
    };
    if (!_isTempId) {
      map['id'] = id;
    }
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      map['description'] = desc;
    }
    if (endAt != null) {
      map['end_at'] = endAt!.toUtc().toIso8601String();
    }
    final iconName = icon?.trim();
    if (iconName != null && iconName.isNotEmpty) {
      map['icon'] = iconName;
    }
    final colorHex = color?.trim();
    if (colorHex != null && colorHex.isNotEmpty) {
      map['color'] = colorHex;
    }
    if (clearSchedule) {
      map['schedule_id'] = null;
    } else if (scheduleCreate != null) {
      map['schedule'] = scheduleCreate;
    } else if (attachScheduleId && scheduleId != null) {
      map['schedule_id'] = int.parse(scheduleId!);
    }
    return map;
  }
}
