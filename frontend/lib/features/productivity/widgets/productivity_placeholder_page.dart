import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';

/// Placeholder productivity screen with a watermark background icon.
class ProductivityPlaceholderPage extends StatelessWidget {
  const ProductivityPlaceholderPage({
    super.key,
    required this.title,
    required this.iconName,
  });

  final String title;
  final String iconName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconData =
        IconRegistry.instance.getIconData(iconName) ?? Icons.circle_outlined;

    return AnvilBackgroundIcon(
      icon: iconData,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Coming soon',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
