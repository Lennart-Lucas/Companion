/// Shared form-value helpers for record icon and color fields.
abstract final class RecordFormUtils {
  static final _colorHexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

  static String? colorHexFromFormValue(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      final rgb = value & 0xFFFFFF;
      return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      if (_colorHexPattern.hasMatch(trimmed)) {
        return trimmed.toUpperCase();
      }
      final withoutHash =
          trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
      if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(withoutHash)) {
        return '#${withoutHash.toUpperCase()}';
      }
      return trimmed;
    }
    return null;
  }

  static int? colorFormValueFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final normalized = hex.startsWith('#') ? hex : '#$hex';
    if (!_colorHexPattern.hasMatch(normalized)) return null;
    final rgb = int.parse(normalized.substring(1), radix: 16);
    return 0xFF000000 | rgb;
  }

  static String? iconFromFormValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }
}
