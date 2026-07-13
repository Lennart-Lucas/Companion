import 'package:flutter/material.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class WeeklySummaryLogButton extends StatelessWidget {
  const WeeklySummaryLogButton({
    super.key,
    required this.label,
    required this.filled,
    required this.color,
    this.enabled = true,
    this.onPressed,
  });

  final String label;
  final bool filled;
  final Color color;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(
      CompanionFormStyles.taskRowPanelRadius,
    );
    final child = Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );

    if (filled) {
      return FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.85),
          minimumSize: const Size(double.infinity, 36),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: trackerStrengthHighColor,
        backgroundColor: trackerStrengthHighColor.withValues(alpha: 0.12),
        side: BorderSide(
          color: trackerStrengthHighColor.withValues(alpha: 0.35),
        ),
        minimumSize: const Size(double.infinity, 36),
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      child: child,
    );
  }
}
