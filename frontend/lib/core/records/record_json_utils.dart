/// Shared JSON parsing helpers for Companion records.
abstract final class RecordJsonUtils {
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

  static String idFromJson(Map<String, dynamic> json) =>
      json['id']?.toString() ?? '';

  static String nameFromJson(Map<String, dynamic> json) =>
      json['name'] as String? ?? '';

  static DateTime? dateTimeFromJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? parentIdFromJson(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static String? parentIdFromFormValue(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static num targetFromJson(dynamic value) {
    if (value is num) return value;
    if (value is String && value.isNotEmpty) {
      return num.tryParse(value) ?? 0;
    }
    return 0;
  }

  static num targetFromFormValue(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return 0;
      return num.tryParse(trimmed) ?? 0;
    }
    return 0;
  }

  static num? optionalTargetFromJson(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String && value.isNotEmpty) {
      return num.tryParse(value);
    }
    return null;
  }

  static num? optionalTargetFromFormValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return num.tryParse(trimmed);
    }
    return null;
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isTempId(String id) => id.startsWith('temp-');
}
