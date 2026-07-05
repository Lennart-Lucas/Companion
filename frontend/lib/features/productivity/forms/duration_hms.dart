/// Helpers for hours:minutes:seconds duration input stored as total seconds.
class DurationHms {
  const DurationHms({
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final int hours;
  final int minutes;
  final int seconds;

  int get totalSeconds => durationHmsToSeconds(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
      );
}

DurationHms secondsToDurationHms(int? totalSeconds) {
  final safe = (totalSeconds ?? 0).clamp(0, 24 * 60 * 60 - 1);
  final hours = safe ~/ 3600;
  final remainder = safe % 3600;
  final minutes = remainder ~/ 60;
  final seconds = remainder % 60;
  return DurationHms(hours: hours, minutes: minutes, seconds: seconds);
}

int durationHmsToSeconds({
  required int hours,
  required int minutes,
  required int seconds,
}) {
  return (hours * 3600) + (minutes * 60) + seconds;
}

String formatDurationHms(int? totalSeconds, {bool pad = true}) {
  final hms = secondsToDurationHms(totalSeconds);
  if (pad) {
    return '${hms.hours}:${hms.minutes.toString().padLeft(2, '0')}:${hms.seconds.toString().padLeft(2, '0')}';
  }
  return '${hms.hours}:${hms.minutes}:${hms.seconds}';
}

/// Compact time for chips — trim leading zero units; pad only after the first unit.
/// Examples: 5 min → `5:00`, 45 sec → `45`, 1h 1m 1s → `1:01:01`.
String formatDurationChip(int? totalSeconds) {
  if (totalSeconds == null || totalSeconds <= 0) return '0:00';
  final hms = secondsToDurationHms(totalSeconds);
  if (hms.hours > 0) {
    return '${hms.hours}:${hms.minutes.toString().padLeft(2, '0')}:${hms.seconds.toString().padLeft(2, '0')}';
  }
  if (hms.minutes > 0) {
    return '${hms.minutes}:${hms.seconds.toString().padLeft(2, '0')}';
  }
  return hms.seconds.toString();
}

/// Prose duration for target chips (e.g. `1 hours 30 minutes`, `30 minutes`).
String formatDurationTargetProse(int? totalSeconds) {
  if (totalSeconds == null || totalSeconds <= 0) return '';
  final hms = secondsToDurationHms(totalSeconds);
  final parts = <String>[];
  if (hms.hours > 0) parts.add('${hms.hours} hours');
  if (hms.minutes > 0) parts.add('${hms.minutes} minutes');
  if (hms.seconds > 0) parts.add('${hms.seconds} seconds');
  return parts.join(' ');
}

int? parseDurationPart(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return int.tryParse(trimmed);
}
