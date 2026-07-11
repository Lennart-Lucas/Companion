import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_stat_items.dart';

/// Two-column stat rows for the tracker detail sidebar.
class TrackerSidebarStatsList extends StatelessWidget {
  const TrackerSidebarStatsList({
    super.key,
    required this.tracker,
    required this.stats,
  });

  final Tracker tracker;
  final TrackerStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = buildTrackerStatItems(tracker: tracker, stats: stats);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.55),
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface.withValues(alpha: 0.92),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outline.withValues(alpha: 0.2),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  items[i].label,
                  style: labelStyle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                items[i].value,
                textAlign: TextAlign.right,
                style: valueStyle,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
