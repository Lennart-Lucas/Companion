import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_theme_controller.dart';
import 'package:frontend/features/productivity/shared/widgets/transparent_form_panel.dart';

/// UI settings: theme selection.
class SettingsUiPage extends StatelessWidget {
  const SettingsUiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = AppThemeController.instance;
    final settingsIcon =
        IconRegistry.instance.getIconData('Gear') ?? Icons.settings_outlined;

    return AnvilBackgroundIcon(
      icon: settingsIcon,
      child: ListenableBuilder(
        listenable: themeController,
        builder: (context, _) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TransparentFormPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Theme',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(themeController.themeId),
                      initialValue: themeController.themeId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: scheme.surface.withValues(alpha: 0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        for (final option in AppThemeId.options)
                          DropdownMenuItem(
                            value: option.$1,
                            child: Row(
                              children: [
                                _ThemePreviewDots(
                                  colors: AppThemeId.previewColorsFor(option.$1),
                                ),
                                const SizedBox(width: 12),
                                Text(option.$2),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (themeId) {
                        if (themeId == null) return;
                        themeController.setTheme(themeId);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemePreviewDots extends StatelessWidget {
  const _ThemePreviewDots({required this.colors});

  final ({Color background, Color surface, Color primary}) colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PreviewDot(color: colors.background),
        const SizedBox(width: 4),
        _PreviewDot(color: colors.surface),
        const SizedBox(width: 4),
        _PreviewDot(color: colors.primary),
      ],
    );
  }
}

class _PreviewDot extends StatelessWidget {
  const _PreviewDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
