import 'package:flutter/material.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';

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
      child: TaskMetaChip(label: watchStatusLabel(value)),
    );
  }
}
