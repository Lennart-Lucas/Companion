import 'package:flutter/material.dart';

/// Page-level section header for the weekly overview dashboard.
class WeeklySummarySection extends StatelessWidget {
  const WeeklySummarySection({
    super.key,
    required this.title,
    this.onViewAll,
    required this.child,
  });

  final String title;
  final VoidCallback? onViewAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('View all >'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
