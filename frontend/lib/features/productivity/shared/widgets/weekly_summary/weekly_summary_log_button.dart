import 'package:flutter/material.dart';

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
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        minimumSize: const Size(double.infinity, 36),
      ),
      child: child,
    );
  }
}
