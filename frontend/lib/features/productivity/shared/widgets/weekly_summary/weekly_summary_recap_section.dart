import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class WeeklySummaryRecapSection extends StatefulWidget {
  const WeeklySummaryRecapSection({super.key, required this.recap});

  final WeeklyRecapStats recap;

  @override
  State<WeeklySummaryRecapSection> createState() =>
      _WeeklySummaryRecapSectionState();
}

class _WeeklySummaryRecapSectionState extends State<WeeklySummaryRecapSection> {
  final _wentWellController = TextEditingController();
  final _planController = TextEditingController();

  @override
  void dispose() {
    _wentWellController.dispose();
    _planController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recap = widget.recap;
    final consistencyPercent = (recap.consistencyPercent * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Week recap',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        TrackerRowPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _RecapStatTile(
                    value: '${recap.checkInsLogged}',
                    label: 'Check-ins logged',
                  ),
                  const SizedBox(width: 8),
                  _RecapStatTile(
                    value: '${recap.tasksCompleted}',
                    label: 'Tasks completed',
                  ),
                  const SizedBox(width: 8),
                  _RecapStatTile(
                    value: recap.trackersTotal == 0
                        ? '—'
                        : '${recap.trackersOnStreak}/${recap.trackersTotal}',
                    label: 'Trackers on-streak',
                  ),
                  const SizedBox(width: 8),
                  _RecapStatTile(
                    value: recap.goalsTotal == 0
                        ? '—'
                        : '${recap.goalsOnTrack}/${recap.goalsTotal}',
                    label: 'Goals on track',
                  ),
                  const SizedBox(width: 8),
                  _RecapStatTile(
                    value: '$consistencyPercent%',
                    label: 'Consistency',
                    valueColor: scheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _NoteField(
                      label: 'What went well last week?',
                      controller: _wentWellController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NoteField(
                      label: 'Plan for this week',
                      controller: _planController,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecapStatTile extends StatelessWidget {
  const _RecapStatTile({
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: CompanionFormStyles.taskListPanelBackground(scheme),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Jot a quick note...',
            filled: true,
            fillColor: CompanionFormStyles.taskListPanelBackground(scheme),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}
