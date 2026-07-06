import 'package:flutter/material.dart';

/// Theme-backed decorations for Companion productivity forms.
class CompanionFormStyles {
  CompanionFormStyles._();

  /// Vertical gap between fields inside an [AnvilFormSection].
  static const double fieldSpacing = 8;

  /// Space above a section title ([AnvilFormSection.headerMarginTop]).
  static const double sectionHeaderMarginTop = 24;

  /// Extra space above sections after the first ([AnvilFormSection.showDivider]).
  static const double sectionHeaderBreakExtraTop = 16;

  /// Space below the section explanation, before fields.
  static const double sectionHeaderMarginBottom = 12;

  /// Below this width, paired form fields in a row stack vertically.
  static const double formFieldRowNarrowBreakpoint = 300;

  /// Scroll padding for full-screen form pages (extra bottom space above action bar).
  static const EdgeInsets formScrollPadding =
      EdgeInsets.fromLTRB(16, 16, 16, 24);

  /// Task list timeline layout tokens.
  static const double taskTimelineWidth = 44;
  static const double taskTimelineLineWidth = 3;
  static const double taskTimelineNodeSize = 28;
  static const double taskTimelineNodeOuterSize = taskTimelineNodeSize + 8;
  static const double taskTimelineIconSize = 26;
  static const double taskTimelineIconBadgeRadius = 8;
  static const double taskTimelineIconBadgeIconSize = 18;
  static const double taskPanelIconBadgeSize = 44;
  static const double taskPanelIconBadgeRadius = 10;
  static const double taskPanelIconBadgeIconSize = 22;
  static const double taskPanelIconBadgeGap = 12;
  static const double taskRowPanelRadius = 10;
  static const double taskRowPanelPadding = 12;
  static const double taskRowBackgroundAlpha = 0.06;
  static const double taskRowVerticalGap = 20;
  static const double taskTimelineLineTopSegment = 8;
  static const double taskTimelineLineRemainingGap = 6;
  static const double taskTimelineLineOverhang =
      (taskRowVerticalGap - taskTimelineLineRemainingGap) / 2;
  static const double taskListChipGap = 6;

  /// Field decoration aligned with [ThemeData.inputDecorationTheme] (Hub borders/fill).
  static InputDecoration fieldDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.inputDecorationTheme;

    return InputDecoration(
      filled: base.filled,
      fillColor: base.fillColor,
      border: base.border,
      enabledBorder: base.enabledBorder,
      focusedBorder: base.focusedBorder,
      errorBorder: base.errorBorder,
      focusedErrorBorder: base.focusedErrorBorder,
      disabledBorder: base.disabledBorder,
      contentPadding: base.contentPadding,
      isDense: base.isDense,
    );
  }

  /// Dense variant for inline list rows (checklist items).
  static InputDecoration denseFieldDecoration(BuildContext context) {
    return fieldDecoration(context).copyWith(isDense: true);
  }

  /// Checklist row background — no border (avoids corner/side outline artifacts).
  static BoxDecoration checklistItemDecoration(
    BuildContext context, {
    bool focused = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = theme.inputDecorationTheme.fillColor ?? scheme.surface;
    final color = focused
        ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.14), fill)
        : fill;

    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    );
  }
}
