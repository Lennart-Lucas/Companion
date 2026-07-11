/// Intermediate target on a goal (backend `goal_milestones`).
class GoalMilestone {
  const GoalMilestone({
    this.id,
    required this.value,
    this.name,
    this.sortOrder = 0,
  });

  final String? id;
  final num value;
  final String? name;
  final int sortOrder;

  factory GoalMilestone.fromJson(Map<String, dynamic> json) {
    return GoalMilestone(
      id: json['id']?.toString(),
      value: _valueFromJson(json['value']),
      name: json['name'] as String?,
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }

  static num _valueFromJson(dynamic value) {
    if (value is num) return value;
    if (value is String && value.isNotEmpty) {
      return num.tryParse(value) ?? 0;
    }
    return 0;
  }

  Map<String, dynamic> toApiJson(int sortOrder) => {
        'value': value,
        if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
        'sort_order': sortOrder,
      };
}

/// Form key and helpers for goal milestones.
abstract final class GoalMilestoneFormKeys {
  static const milestones = 'milestones';
}

abstract final class GoalMilestoneFormValues {
  static List<Map<String, dynamic>> emptyFormEntries() => [];

  static List<Map<String, dynamic>> templatesToFormEntries(
    List<GoalMilestone> milestones,
  ) {
    final sorted = List<GoalMilestone>.from(milestones)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [
      for (final item in sorted)
        {
          'value': item.value,
          if (item.name != null && item.name!.isNotEmpty) 'name': item.name,
        },
    ];
  }

  static List<GoalMilestone> templatesFromJson(dynamic value) {
    if (value is! List) return const [];
    final items = <GoalMilestone>[];
    for (final entry in value) {
      if (entry is Map) {
        items.add(
          GoalMilestone.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
    }
    return items;
  }

  /// Builds API `milestones` array; skips blank or invalid values.
  static List<Map<String, dynamic>> toApiPayload(dynamic raw) {
    if (raw is! List) return [];
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      if (entry is! Map) continue;
      final value = _valueFromForm(entry['value']);
      if (value == null || value <= 0) continue;
      final name = (entry['name'] as String?)?.trim();
      items.add({
        'value': value,
        if (name != null && name.isNotEmpty) 'name': name,
        'sort_order': items.length,
      });
    }
    return items;
  }

  static num? _valueFromForm(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return num.tryParse(trimmed);
    }
    return null;
  }

  /// Parses milestone values from form list entries (preserves list order).
  static List<num> valuesFromForm(dynamic raw) {
    if (raw is! List) return const [];
    final values = <num>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final value = _valueFromForm(entry['value']);
      if (value != null) values.add(value);
    }
    return values;
  }
}

/// Client-side milestone validation mirroring backend rules.
abstract final class GoalMilestoneValidation {
  static String? validateFormValues(Map<String, dynamic> values) {
    final goalType = values['goal_type'] as String? ?? 'count';
    if (goalType == 'pulse') return null;

    final raw = values[GoalMilestoneFormKeys.milestones];
    if (raw is! List || raw.isEmpty) return null;

    final targetRaw = values['target'];
    final target = targetRaw is num
        ? targetRaw
        : num.tryParse(targetRaw?.toString().trim() ?? '');
    if (target == null || target <= 0) {
      return 'Set a valid target before adding milestones';
    }

    final direction = values['direction'] as String? ?? 'increasing';
    final milestoneValues = GoalMilestoneFormValues.valuesFromForm(raw);
    if (milestoneValues.isEmpty) return null;

    return validateValues(
      target: target,
      direction: direction,
      values: milestoneValues,
    );
  }

  static String? validateValues({
    required num target,
    required String direction,
    required List<num> values,
  }) {
    if (values.isEmpty) return null;

    final unique = values.toSet();
    if (unique.length != values.length) {
      return 'Milestone values must be unique';
    }

    for (final value in values) {
      if (direction == 'increasing') {
        if (value <= 0) {
          return 'Milestone value must be greater than 0';
        }
        if (value >= target) {
          return 'Milestone value must be less than target for increasing goals';
        }
      } else if (value <= target) {
        return 'Milestone value must be greater than target for decreasing goals';
      }
    }

    if (direction == 'increasing') {
      for (var i = 1; i < values.length; i++) {
        if (values[i] <= values[i - 1]) {
          return 'Milestones must be in ascending order for increasing goals';
        }
      }
    } else {
      for (var i = 1; i < values.length; i++) {
        if (values[i] >= values[i - 1]) {
          return 'Milestones must be in descending order for decreasing goals';
        }
      }
    }

    return null;
  }
}
