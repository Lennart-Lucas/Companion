import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/widgets/project_display.dart';

String formatEventDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final date = formatProjectDate(local);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$date $hour:$minute';
}

String? eventDateTimeRangeLabel(DateTime start, DateTime? end) {
  if (end != null) {
    final startLocal = start.toLocal();
    final endLocal = end.toLocal();
    final sameDay = startLocal.year == endLocal.year &&
        startLocal.month == endLocal.month &&
        startLocal.day == endLocal.day;
    if (sameDay) {
      return '${formatProjectDate(startLocal)} '
          '${_formatTime(startLocal)} – ${_formatTime(endLocal)}';
    }
    return '${formatEventDateTime(start)} – ${formatEventDateTime(end)}';
  }
  return formatEventDateTime(start);
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String eventSubtitle(Event event) {
  return eventDateTimeRangeLabel(event.startAt, event.endAt) ?? '';
}
