import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';

/// Responsive layout helpers for productivity list UIs.
abstract final class CompanionLayout {
  static const compactBreakpoint = 600.0;

  /// Default horizontal padding on task timeline list pages.
  static const listHorizontalPadding = 16.0;

  /// True when the viewport is narrower than [compactBreakpoint].
  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < compactBreakpoint;
  }

  /// Minimum width for a tracker list tile in the wrap grid.
  static const trackerListTileMinWidth = 760.0;

  /// Left inset cancelled when buckets bleed inside a padded list.
  static const double compactBucketBleedLeft = listHorizontalPadding;

  /// Right inset cancelled when buckets bleed inside a padded list.
  static const double compactBucketBleedRight =
      listHorizontalPadding + CompanionFormStyles.taskListTrailingInset;
}
