/// Formats Companion API error responses for display.
String formatCompanionApiError({
  required int statusCode,
  required dynamic body,
  required String action,
}) {
  final detail = extractCompanionApiErrorDetail(body);
  if (detail != null && detail.isNotEmpty) {
    return '$action failed (HTTP $statusCode): $detail';
  }
  return '$action failed (HTTP $statusCode)';
}

/// Extracts a human-readable message from a FastAPI or plain-text error body.
String? extractCompanionApiErrorDetail(dynamic body) {
  if (body is String) {
    final trimmed = body.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (body is Map) {
    final detail = body['detail'];
    if (detail is String) return detail;
    if (detail is List) {
      final parts = <String>[];
      for (final item in detail) {
        if (item is Map) {
          final msg = item['msg'];
          if (msg == null) continue;
          final loc = item['loc'];
          if (loc is List && loc.isNotEmpty) {
            parts.add('${loc.join('.')}: $msg');
          } else {
            parts.add(msg.toString());
          }
        }
      }
      if (parts.isNotEmpty) return parts.join('; ');
    }
  }
  return null;
}
