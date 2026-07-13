import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';

/// Tappable weekly summary row shown on Sunday in the overview timeline.
class WeeklySummaryTimelineTile extends StatelessWidget {
  const WeeklySummaryTimelineTile({
    super.key,
    required this.weekStart,
    required this.preview,
    required this.onTap,
    this.isFirst = true,
    this.isLast = false,
    this.hideLeadingIcon = false,
  });

  static const rowHeight = 112.0;

  final DateTime weekStart;
  final WeeklySummaryPreview preview;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;
  final bool hideLeadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rangeLabel = formatWeekRangeLabel(weekStart);
    final trackerPercent = preview.trackerSuccessPercent;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: CompanionFormStyles.taskRowVerticalGap,
      ),
      child: ClipRect(
        clipBehavior: Clip.none,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskTimelineColumn(
                isFirst: isFirst,
                isLast: isLast,
                statusNode: const _WeeklySummaryTimelineNode(),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(
                      CompanionFormStyles.taskRowPanelRadius,
                    ),
                    child: TaskRowPanel(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!hideLeadingIcon) ...[
                            TaskTimelineIconBadge(
                              color: scheme.primary,
                              defaultIconName: 'Chart Pie',
                              materialFallback: Icons.summarize_outlined,
                            ),
                            const SizedBox(
                              width: CompanionFormStyles.taskPanelIconBadgeGap,
                            ),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weekly summary',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  rangeLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: CompanionFormStyles.taskListChipGap,
                                  runSpacing:
                                      CompanionFormStyles.taskListChipGap,
                                  children: [
                                    TaskMetaChip(
                                      label: preview.tasksCompleted == 1
                                          ? '1 task done'
                                          : '${preview.tasksCompleted} tasks done',
                                      tintColor: companionSuccessColor,
                                      leading: Icon(
                                        taskCompletedStatusChipIcon(),
                                        size: 14,
                                        color: companionSuccessColor,
                                      ),
                                    ),
                                    if (trackerPercent != null)
                                      TaskMetaChip(
                                        label:
                                            '${(trackerPercent * 100).round()}% trackers',
                                        tintColor: scheme.primary,
                                        leading: Icon(
                                          Icons.show_chart_outlined,
                                          size: 14,
                                          color: scheme.primary,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklySummaryTimelineNode extends StatelessWidget {
  const _WeeklySummaryTimelineNode();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const nodeSize = CompanionFormStyles.taskTimelineNodeSize;

    return SizedBox(
      width: nodeSize + 8,
      height: nodeSize + 8,
      child: Center(
        child: _weeklySummaryTimelineIcon(
          size: CompanionFormStyles.taskTimelineIconSize,
          color: scheme.primary,
        ),
      ),
    );
  }
}

Widget _weeklySummaryTimelineIcon({
  required double size,
  required Color color,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        FaIcon(FontAwesomeIcons.circle, size: size, color: color),
        FaIcon(
          FontAwesomeIcons.chartPie,
          size: size * 0.42,
          color: color,
        ),
      ],
    ),
  );
}
