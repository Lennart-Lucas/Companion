import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_recap_stat_strip.dart';

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
    final compact = CompanionLayout.isCompact(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeeklySummaryRecapStatStrip(recap: widget.recap),
        const SizedBox(height: 20),
        if (compact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NoteField(
                title: 'What went well last week?',
                controller: _wentWellController,
              ),
              const SizedBox(height: 12),
              _NoteField(
                title: 'Plan for this week',
                controller: _planController,
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NoteField(
                  title: 'What went well last week?',
                  controller: _wentWellController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NoteField(
                  title: 'Plan for this week',
                  controller: _planController,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.title, required this.controller});

  final String title;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.primary,
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
            fillColor: scheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                CompanionFormStyles.taskRowPanelRadius,
              ),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}
