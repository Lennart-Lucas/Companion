import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/features/productivity/forms/task_planned_deadline_fields.dart';
import 'package:frontend/features/productivity/models/task_schedule.dart';
import 'package:frontend/features/productivity/models/task_subtask.dart';

/// Shared list-display record for Companion productivity entities.
abstract class ProductivityRecord extends Record {
  String get name;

  static String idFromJson(Map<String, dynamic> json) =>
      json['id']?.toString() ?? '';

  static String nameFromJson(Map<String, dynamic> json) =>
      json['name'] as String? ?? '';

  /// Flattens Anvil record envelopes (`{ id, data: { ... } }`) for parsing.
  static Map<String, dynamic> unwrapJson(Map<String, dynamic> json) {
    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      return {
        ...nested,
        if (json['id'] != null) 'id': json['id'],
      };
    }
    if (nested is Map) {
      return {
        ...Map<String, dynamic>.from(nested),
        if (json['id'] != null) 'id': json['id'],
      };
    }
    return json;
  }
}

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
  final int milestoneCount;
  final Map<String, dynamic>? scheduleCreate;

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
    this.milestoneCount = 0,
    this.scheduleCreate,
  });

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _scheduleIdFromJson(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static String? _scheduleIdFromFormValue(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static num _targetFromJson(dynamic value) {
    if (value is num) return value;
    if (value is String && value.isNotEmpty) {
      return num.tryParse(value) ?? 0;
    }
    return 0;
  }

  static num _targetFromFormValue(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return 0;
      return num.tryParse(trimmed) ?? 0;
    }
    return 0;
  }

  static int _milestoneCountFromJson(dynamic value) {
    if (value is List) return value.length;
    return 0;
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    final startDate = _dateTimeFromJson(data['start_date']);
    return Goal(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      color: data['color'] as String?,
      scheduleId: _scheduleIdFromJson(data['schedule_id']),
      startDate: startDate ?? DateTime.now(),
      endDate: _dateTimeFromJson(data['end_date']),
      goalType: data['goal_type'] as String? ?? GoalType.count,
      target: _targetFromJson(data['target']),
      unit: data['unit'] as String? ?? '',
      direction: data['direction'] as String? ?? GoalDirection.increasing,
      milestoneCount: _milestoneCountFromJson(data['milestones']),
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

    return Goal(
      id: resolvedId,
      name: name,
      description: (values['description'] as String?)?.trim(),
      icon: Project._iconFromFormValue(values['icon']),
      color: Project._colorHexFromFormValue(values['color']),
      scheduleId: _scheduleIdFromFormValue(values['existing_schedule_id']),
      startDate: _startDateFromFormValues(values),
      endDate: values['end_date'] as DateTime?,
      goalType: values['goal_type'] as String? ?? GoalType.count,
      target: _targetFromFormValue(values['target']),
      unit: (values['unit'] as String? ?? '').trim(),
      direction: values['direction'] as String? ?? GoalDirection.increasing,
      scheduleCreate: schedule.toScheduleCreateJson(preferAnchorField: true),
    );
  }

  Map<String, dynamic> toFormValues() => {
        'name': name,
        'description': description ?? '',
        'icon': icon,
        'color': Project._colorFormValueFromHex(color),
        'end_date': endDate,
        'goal_type': goalType,
        'target': target,
        'unit': unit,
        'direction': direction,
        TaskScheduleFormKeys.anchor:
            DateTime(startDate.year, startDate.month, startDate.day),
        if (scheduleId != null) 'existing_schedule_id': scheduleId,
      };

  bool get _isTempId => id.startsWith('temp-');

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

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _parentIdFromJson(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static String? _parentIdFromFormValue(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static num? _targetFromJson(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String && value.isNotEmpty) {
      return num.tryParse(value);
    }
    return null;
  }

  static num? _targetFromFormValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return num.tryParse(trimmed);
    }
    return null;
  }

  factory Tracker.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    final startDate = _dateTimeFromJson(data['start_date']);
    final parsedStart = startDate ?? DateTime.now();
    final localStart = parsedStart.toLocal();
    return Tracker(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      color: data['color'] as String?,
      goalId: _parentIdFromJson(data['goal_id']),
      scheduleId: _parentIdFromJson(data['schedule_id']),
      startDate: DateTime(
        localStart.year,
        localStart.month,
        localStart.day,
      ),
      endDate: _dateTimeFromJson(data['end_date']),
      checkInType:
          data['check_in_type'] as String? ?? TrackerCheckInType.task,
      target: _targetFromJson(data['target']),
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
      icon: Project._iconFromFormValue(values['icon']),
      color: Project._colorHexFromFormValue(values['color']),
      goalId: _parentIdFromFormValue(values['goal_id']),
      scheduleId: _parentIdFromFormValue(values['existing_schedule_id']),
      startDate: _startDateFromFormValues(values),
      endDate: values['end_date'] as DateTime?,
      checkInType: checkInType,
      target: _targetFromFormValue(values['target']),
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
        'color': Project._colorFormValueFromHex(color),
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

  bool get _isTempId => id.startsWith('temp-');

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

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _parentIdFromFormValue(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    final startAt = _dateTimeFromJson(data['start_at']);
    return Event(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      icon: data['icon'] as String?,
      color: data['color'] as String?,
      startAt: startAt ?? DateTime.now(),
      endAt: _dateTimeFromJson(data['end_at']),
      scheduleId: _parentIdFromFormValue(data['schedule_id']),
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
        _parentIdFromFormValue(values[TaskScheduleFormKeys.existingScheduleId]);
    final originalScheduleId = _parentIdFromFormValue(
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
      icon: Project._iconFromFormValue(values['icon']),
      color: Project._colorHexFromFormValue(values['color']),
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
        'color': Project._colorFormValueFromHex(color),
        if (scheduleId != null)
          TaskScheduleFormKeys.existingScheduleId: scheduleId,
      };

  bool get _isTempId => id.startsWith('temp-');

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

class Project extends ProductivityRecord {
  @override
  final RecordId id;
  @override
  RecordType get recordType => 'projects';
  @override
  final String name;
  final String? description;
  final String status;
  final DateTime? startDate;
  final DateTime? deadline;
  final String? goalId;
  final String? icon;
  final String? color;

  Project({
    required this.id,
    required this.name,
    this.description,
    this.status = 'planning',
    this.startDate,
    this.deadline,
    this.goalId,
    this.icon,
    this.color,
  });

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _goalIdFromJson(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    return Project(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      status: data['status'] as String? ?? 'planning',
      startDate: _dateTimeFromJson(data['start_date']),
      deadline: _dateTimeFromJson(data['deadline']),
      goalId: _goalIdFromJson(data['goal_id']),
      icon: data['icon'] as String?,
      color: data['color'] as String?,
    );
  }

  static final _colorHexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

  static String? _colorHexFromFormValue(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      final rgb = value & 0xFFFFFF;
      return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static int? _colorFormValueFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final normalized = hex.startsWith('#') ? hex : '#$hex';
    if (!_colorHexPattern.hasMatch(normalized)) return null;
    final rgb = int.parse(normalized.substring(1), radix: 16);
    return 0xFF000000 | rgb;
  }

  static String? _iconFromFormValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }

  factory Project.fromFormValues(
    Map<String, dynamic> values, {
    String? id,
  }) {
    final name = (values['name'] as String? ?? '').trim();
    final goalRaw = values['goal_id'];
    final goalId = goalRaw == null || goalRaw.toString().isEmpty
        ? null
        : goalRaw.toString();
    return Project(
      id: id ?? 'temp-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: (values['description'] as String?)?.trim(),
      status: values['status'] as String? ?? 'planning',
      startDate: values['start_date'] as DateTime?,
      deadline: values['deadline'] as DateTime?,
      goalId: goalId,
      icon: _iconFromFormValue(values['icon']),
      color: _colorHexFromFormValue(values['color']),
    );
  }

  Map<String, dynamic> toFormValues() => {
        'name': name,
        'description': description ?? '',
        'status': status,
        'start_date': startDate,
        'deadline': deadline,
        'goal_id': goalId ?? '',
        'icon': icon,
        'color': _colorFormValueFromHex(color),
      };

  bool get _isTempId => id.startsWith('temp-');

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'status': status,
    };
    if (!_isTempId) {
      map['id'] = id;
    }
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      map['description'] = desc;
    }
    if (startDate != null) {
      map['start_date'] = startDate!.toUtc().toIso8601String();
    }
    if (deadline != null) {
      map['deadline'] = deadline!.toUtc().toIso8601String();
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
    return map;
  }
}

class Task extends ProductivityRecord {
  @override
  final RecordId id;
  @override
  RecordType get recordType => 'tasks';
  @override
  final String name;
  final String? description;
  final DateTime? plannedAt;
  final DateTime? deadline;
  final String status;
  final String priority;
  final String? projectId;
  final String? goalId;
  final String? scheduleId;
  final bool isRecurring;
  final Map<String, dynamic>? scheduleCreate;
  final bool clearSchedule;
  final bool attachScheduleId;
  final List<TaskSubtaskTemplate> subtasks;
  final DateTime? updatedAt;

  Task({
    required this.id,
    required this.name,
    this.description,
    this.plannedAt,
    this.deadline,
    this.status = 'pending',
    this.priority = 'medium',
    this.projectId,
    this.goalId,
    this.scheduleId,
    this.isRecurring = false,
    this.scheduleCreate,
    this.clearSchedule = false,
    this.attachScheduleId = false,
    this.subtasks = const [],
    this.updatedAt,
  });

  static String? _parentIdFromJson(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static String? _parentIdFromFormValue(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    return Task(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      plannedAt: _dateTimeFromJson(data['planned_at']),
      deadline: _dateTimeFromJson(data['deadline']),
      status: data['status'] as String? ?? 'pending',
      priority: data['priority'] as String? ?? 'medium',
      projectId: _parentIdFromJson(data['project_id']),
      goalId: _parentIdFromJson(data['goal_id']),
      scheduleId: _parentIdFromJson(data['schedule_id']),
      isRecurring: data['is_recurring'] == true,
      subtasks: TaskSubtaskFormValues.templatesFromJson(data['subtasks']),
      updatedAt: _dateTimeFromJson(data['updated_at']),
    );
  }

  /// Builds a task from [AnvilForm] values. Pass [id] for updates; omit for create.
  factory Task.fromFormValues(
    Map<String, dynamic> values, {
    String? id,
  }) {
    final name = (values['name'] as String? ?? '').trim();
    final resolvedId = id ?? 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final schedule = TaskScheduleFormValues.fromFormMap(values);
    final mode = schedule.mode;
    final existingScheduleId = schedule.existingScheduleId ??
        _parentIdFromFormValue(values[TaskScheduleFormKeys.existingScheduleId]);
    final originalScheduleId = _parentIdFromFormValue(
      values[TaskScheduleFormKeys.originalScheduleId],
    );
    final isUpdate = !resolvedId.startsWith('temp-');
    final subtasksPayload =
        TaskSubtaskFormValues.toApiPayload(values[TaskSubtaskFormKeys.subtasks]);
    final deadline = values[taskDeadlineFieldKey] as DateTime?;
    final plannedAt = values[taskPlannedAtFieldKey] as DateTime?;
    final fallbackAnchor = schedule.repeatEnabled
        ? schedule.startDate ?? deadline ?? plannedAt
        : deadline ?? plannedAt;

    Map<String, dynamic>? scheduleCreate;
    bool clearSchedule = false;
    bool attachScheduleId = false;
    String? scheduleId;

    switch (mode) {
      case TaskScheduleMode.off:
        if (isUpdate && (originalScheduleId ?? existingScheduleId) != null) {
          clearSchedule = true;
        }
      case TaskScheduleMode.oneOff:
        scheduleCreate = schedule.oneOffScheduleFromDeadline(deadline);
      case TaskScheduleMode.repeating:
        scheduleCreate = schedule.toScheduleCreateJson(
          fallbackAnchor: fallbackAnchor,
        );
        scheduleId = null;
      case TaskScheduleMode.link:
        scheduleId = existingScheduleId;
        attachScheduleId = !isUpdate && scheduleId != null;
    }

    final usesTaskDates = TaskScheduleMode.usesTaskDates(mode);

    return Task(
      id: resolvedId,
      name: name,
      description: (values['description'] as String?)?.trim(),
      plannedAt: usesTaskDates ? plannedAt : null,
      deadline: usesTaskDates ? deadline : null,
      status: usesTaskDates
          ? values[taskStatusFieldKey] as String? ?? 'pending'
          : 'pending',
      priority: values['priority'] as String? ?? 'medium',
      projectId: _parentIdFromFormValue(values['project_id']),
      goalId: _parentIdFromFormValue(values['goal_id']),
      scheduleId: scheduleId,
      isRecurring: mode == TaskScheduleMode.repeating,
      scheduleCreate: scheduleCreate,
      clearSchedule: clearSchedule,
      attachScheduleId: attachScheduleId,
      subtasks: [
        for (final row in subtasksPayload)
          TaskSubtaskTemplate(title: row['title'] as String),
      ],
    );
  }

  Map<String, dynamic> toFormValues() => {
        'name': name,
        'description': description ?? '',
        'planned_at': plannedAt,
        'deadline': deadline,
        'status': status,
        'priority': priority,
        'project_id': projectId ?? '',
        'goal_id': goalId ?? '',
        if (scheduleId != null)
          TaskScheduleFormKeys.existingScheduleId: scheduleId,
        TaskSubtaskFormKeys.subtasks:
            TaskSubtaskFormValues.templatesToFormEntries(subtasks),
      };

  bool get _isTempId => id.startsWith('temp-');

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'status': status,
      'priority': priority,
    };
    if (!_isTempId) {
      map['id'] = id;
    }
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      map['description'] = desc;
    }
    if (plannedAt != null) {
      map['planned_at'] = plannedAt!.toUtc().toIso8601String();
    }
    if (deadline != null) {
      map['deadline'] = deadline!.toUtc().toIso8601String();
    }
    if (!_isTempId) {
      map['project_id'] =
          projectId != null ? int.parse(projectId!) : null;
      map['goal_id'] = goalId != null ? int.parse(goalId!) : null;
    } else {
      if (projectId != null) {
        map['project_id'] = int.parse(projectId!);
      }
      if (goalId != null) {
        map['goal_id'] = int.parse(goalId!);
      }
    }

    if (clearSchedule) {
      map['schedule_id'] = null;
    } else if (scheduleCreate != null) {
      map['schedule'] = scheduleCreate;
    } else if (attachScheduleId && scheduleId != null) {
      map['schedule_id'] = int.parse(scheduleId!);
    }

    if (_isTempId && subtasks.isNotEmpty) {
      map['subtasks'] = [
        for (var i = 0; i < subtasks.length; i++)
          subtasks[i].toApiJson(i),
      ];
    }

    return map;
  }

  /// Merges task fields with schedule form values for edit hydration.
  Map<String, dynamic> toFormValuesWithSchedule(
    TaskScheduleFormValues schedule,
  ) =>
      {
        ...toFormValues(),
        ...schedule.toFormMap(),
        if (scheduleId != null)
          TaskScheduleFormKeys.existingScheduleId: scheduleId,
      };
}
