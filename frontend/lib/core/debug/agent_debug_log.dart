import 'dart:convert';
import 'dart:io';

/// Session debug logger for agent investigations (desktop/dev only).
void agentDebugLog({
  required String hypothesisId,
  required String location,
  required String message,
  Map<String, dynamic>? data,
  String runId = 'pre-fix',
}) {
  // #region agent log
  try {
    final payload = jsonEncode({
      'sessionId': '509e4a',
      'runId': runId,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data ?? const <String, dynamic>{},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    File(
      r'c:\Users\Lennart Lucas\Documents\Github\Companion\debug-509e4a.log',
    ).writeAsStringSync('$payload\n', mode: FileMode.append, flush: true);
  } catch (_) {}
  // #endregion
}
