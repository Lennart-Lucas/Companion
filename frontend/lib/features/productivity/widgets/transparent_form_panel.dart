import 'package:flutter/material.dart';

/// Light wrapper for form fields on pages with [AnvilBackgroundIcon].
///
/// By default no fill — only padding — so the scaffold and watermark show through.
/// Pass [opacity] for a subtle [ColorScheme.surface] tint (no primary color blend).
class TransparentFormPanel extends StatelessWidget {
  const TransparentFormPanel({
    super.key,
    required this.child,
    this.opacity = 0,
    this.showBorder = false,
  });

  final Widget child;

  /// Surface fill opacity (0 = transparent). Uses [ColorScheme.surface] only.
  final double opacity;

  /// Optional hairline border from [ColorScheme.onSurface].
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clampedOpacity = opacity.clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: clampedOpacity > 0
            ? scheme.surface.withValues(alpha: clampedOpacity)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: showBorder
            ? Border.all(
                color: scheme.onSurface.withValues(alpha: 0.12),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: child,
      ),
    );
  }
}
