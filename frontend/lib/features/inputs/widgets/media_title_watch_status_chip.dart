import 'package:flutter/material.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';

IconData _watchStatusIcon(String status) {
  switch (status) {
    case MediaWatchStatus.watching:
      return Icons.play_circle_outline;
    case MediaWatchStatus.completed:
      return Icons.check_circle_outline;
    case MediaWatchStatus.onHold:
      return Icons.pause_circle_outline;
    case MediaWatchStatus.dropped:
      return Icons.cancel_outlined;
    case MediaWatchStatus.planToWatch:
    default:
      return Icons.bookmark_border;
  }
}

class MediaTitleWatchStatusChip extends StatelessWidget {
  const MediaTitleWatchStatusChip({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Watch status',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final status in MediaWatchStatus.all)
          PopupMenuItem<String>(
            value: status,
            child: Text(watchStatusLabel(status)),
          ),
      ],
      child: TaskMetaChip(
        label: watchStatusLabel(value),
        tintColor: scheme.primary,
        bordered: false,
        leading: Icon(
          _watchStatusIcon(value),
          size: 14,
          color: scheme.primary,
        ),
      ),
    );
  }
}
