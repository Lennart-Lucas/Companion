import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/core/records/record_json_utils.dart';
import 'package:frontend/core/scheduling/schedule_form_values.dart';
import 'package:frontend/features/productivity/tasks/forms/task_planned_deadline_fields.dart';
import 'package:frontend/features/productivity/tasks/models/task_subtask.dart';

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

  factory Task.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    return Task(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      description: data['description'] as String?,
      plannedAt: RecordJsonUtils.dateTimeFromJson(data['planned_at']),
      deadline: RecordJsonUtils.dateTimeFromJson(data['deadline']),
      status: data['status'] as String? ?? 'pending',
      priority: data['priority'] as String? ?? 'medium',
      projectId: RecordJsonUtils.parentIdFromJson(data['project_id']),
      goalId: RecordJsonUtils.parentIdFromJson(data['goal_id']),
      scheduleId: RecordJsonUtils.parentIdFromJson(data['schedule_id']),
      isRecurring: data['is_recurring'] == true,
      subtasks: TaskSubtaskFormValues.templatesFromJson(data['subtasks']),
      updatedAt: RecordJsonUtils.dateTimeFromJson(data['updated_at']),
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
        RecordJsonUtils.parentIdFromFormValue(
          values[TaskScheduleFormKeys.existingScheduleId],
        );
    final originalScheduleId = RecordJsonUtils.parentIdFromFormValue(
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
      projectId: RecordJsonUtils.parentIdFromFormValue(values['project_id']),
      goalId: RecordJsonUtils.parentIdFromFormValue(values['goal_id']),
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

  bool get _isTempId => RecordJsonUtils.isTempId(id);

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
