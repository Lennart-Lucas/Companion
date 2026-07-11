import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/core/records/record_json_utils.dart';
import 'package:frontend/core/records/record_form_utils.dart';

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

  factory Project.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    return Project(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      status: data['status'] as String? ?? 'planning',
      startDate: RecordJsonUtils.dateTimeFromJson(data['start_date']),
      deadline: RecordJsonUtils.dateTimeFromJson(data['deadline']),
      goalId: RecordJsonUtils.parentIdFromJson(data['goal_id']),
      icon: data['icon'] as String?,
      color: data['color'] as String?,
    );
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
      icon: RecordFormUtils.iconFromFormValue(values['icon']),
      color: RecordFormUtils.colorHexFromFormValue(values['color']),
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
        'color': RecordFormUtils.colorFormValueFromHex(color),
      };

  bool get _isTempId => RecordJsonUtils.isTempId(id);

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
