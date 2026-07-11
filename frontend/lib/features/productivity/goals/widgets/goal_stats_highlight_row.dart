import 'package:flutter/material.dart';

import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/core/ui/outcome_colors.dart';

import 'package:frontend/features/productivity/models/productivity_record.dart';

import 'package:frontend/features/productivity/goals/services/goal_stats.dart';

import 'package:frontend/features/productivity/goals/widgets/goal_stat_items.dart';

import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';



enum GoalStatsHighlightLayout {

  horizontal,

  vertical,

}



class GoalStatsHighlightRow extends StatelessWidget {

  const GoalStatsHighlightRow({

    super.key,

    required this.stats,

    this.goal,

    this.layout = GoalStatsHighlightLayout.horizontal,

    this.direction = Axis.horizontal,

  });



  static const _consistencyTooltip =

      'Consistency\n\n'

      'Measures how often you logged check-ins over the last 30 scheduled days.\n\n'

      'Consistency = logged days ÷ scheduled days × 100';



  final GoalStats stats;

  final Goal? goal;

  final GoalStatsHighlightLayout layout;

  final Axis direction;



  GoalStatsHighlightLayout get _resolvedLayout {

    if (layout != GoalStatsHighlightLayout.horizontal) {

      return layout;

    }

    return direction == Axis.vertical

        ? GoalStatsHighlightLayout.vertical

        : GoalStatsHighlightLayout.horizontal;

  }



  bool get _useSidebarMetrics =>

      goal != null && _resolvedLayout == GoalStatsHighlightLayout.vertical;



  @override

  Widget build(BuildContext context) {

    final sidebarStyle = _resolvedLayout == GoalStatsHighlightLayout.vertical;
    final accentColor = productivityPrimaryAccent(context);

    final cards = _useSidebarMetrics

        ? _sidebarCards(goal!, stats, sidebarStyle, accentColor)

        : _defaultCards(stats, sidebarStyle, accentColor);



    switch (_resolvedLayout) {

      case GoalStatsHighlightLayout.vertical:

        return Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            for (var i = 0; i < cards.length; i++) ...[

              if (i > 0) const SizedBox(height: 10),

              cards[i],

            ],

          ],

        );

      case GoalStatsHighlightLayout.horizontal:

        return Row(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            for (var i = 0; i < cards.length; i++) ...[

              if (i > 0) const SizedBox(width: 12),

              Expanded(child: cards[i]),

            ],

          ],

        );

    }

  }



  List<Widget> _sidebarCards(

    Goal goal,

    GoalStats stats,

    bool sidebarStyle,

    Color accentColor,

  ) {

    final progressPercent = stats.progressPercent.round();

    final consistencyPercent = (stats.consistency * 100).round();

    final progressFraction =
        (stats.progressPercent / 100).clamp(0.0, 1.0);

    final etaLabel = formatGoalEtaShort(stats.etaWeeks);
    final etaRingFraction = computeGoalEtaRingFraction(
      goal,
      stats.etaWeeks,
    );

    return [

      _GoalHighlightCard(

        ringFraction: progressFraction,

        ringColor: accentColor,

        ringCenterText: '$progressPercent%',

        valueText: '$progressPercent%',

        label: 'Progress to goal',

        sidebarStyle: sidebarStyle,

      ),

      _GoalHighlightCard(

        ringFraction: etaRingFraction,

        ringColor: accentColor,

        valueText: etaLabel,

        label: 'ETA at current pace',

        sidebarStyle: sidebarStyle,

      ),

      _GoalHighlightCard(

        ringFraction: stats.consistency.clamp(0.0, 1.0),

        ringColor: companionTrackerBlue,

        ringCenterText: '$consistencyPercent%',

        valueText: '$consistencyPercent%',

        label: 'Consistency',

        tooltip: _consistencyTooltip,

        sidebarStyle: sidebarStyle,

      ),

    ];

  }



  List<Widget> _defaultCards(
    GoalStats stats,
    bool sidebarStyle,
    Color accentColor,
  ) {

    final progressPercent = stats.progressPercent.round();

    final consistencyPercent = (stats.consistency * 100).round();

    final streakFraction = stats.bestStreak == 0

        ? 0.0

        : (stats.currentStreak / stats.bestStreak).clamp(0.0, 1.0);



    return [

      _GoalHighlightCard(

        ringFraction: (stats.progressPercent / 100).clamp(0.0, 1.0),

        ringColor: trackerStrengthHighColor,

        ringCenterText: '$progressPercent%',

        valueText: '$progressPercent%',

        label: 'Progress',

        sidebarStyle: sidebarStyle,

      ),

      _GoalHighlightCard(

        ringFraction: streakFraction,

        ringColor: trackerStrengthHighColor,

        ringCenterText: '${stats.currentStreak}',

        valueText: '${stats.currentStreak} / ${stats.bestStreak} days',

        label: 'Streak vs best',

        sidebarStyle: sidebarStyle,

      ),

      _GoalHighlightCard(

        ringFraction: stats.consistency.clamp(0.0, 1.0),

        ringColor: accentColor,

        ringCenterText: '$consistencyPercent%',

        valueText:

            '${stats.consistencyLogged}/${stats.consistencyScheduled}',

        label: 'Consistency',

        tooltip: _consistencyTooltip,

        sidebarStyle: sidebarStyle,

      ),

    ];

  }

}



class _GoalHighlightCard extends StatelessWidget {

  const _GoalHighlightCard({

    required this.ringFraction,

    required this.ringColor,

    required this.valueText,

    required this.label,

    this.ringCenterText,

    this.tooltip,

    this.sidebarStyle = false,

  });



  static const _ringSize = 52.0;

  static const _sidebarRingSize = 56.0;



  final double ringFraction;

  final Color ringColor;

  final String? ringCenterText;

  final String valueText;

  final String label;

  final String? tooltip;

  final bool sidebarStyle;



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final scheme = theme.colorScheme;

    final ringSize = sidebarStyle ? _sidebarRingSize : _ringSize;



    final card = TrackerRowPanel(

      child: Row(

        children: [

          TrackerProgressRing(

            fraction: ringFraction,

            color: ringColor,

            size: ringSize,

            strokeWidth: sidebarStyle ? 5.0 : 4.5,

            center: ringCenterText == null

                ? null

                : Text(

                    ringCenterText!,

                    style: theme.textTheme.labelMedium?.copyWith(

                      fontWeight: FontWeight.w700,

                      color: scheme.onSurface.withValues(alpha: 0.92),

                      height: 1,

                    ),

                  ),

          ),

          SizedBox(width: sidebarStyle ? 16 : 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                Text(

                  valueText,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: (sidebarStyle

                          ? theme.textTheme.titleLarge

                          : theme.textTheme.titleMedium)

                      ?.copyWith(

                    fontWeight: FontWeight.w700,

                    color: scheme.onSurface,

                  ),

                ),

                const SizedBox(height: 2),

                Text(

                  label,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: theme.textTheme.bodyMedium?.copyWith(

                    color: scheme.onSurface.withValues(alpha: 0.55),

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );



    if (tooltip == null) return card;



    return Tooltip(

      message: tooltip!,

      preferBelow: false,

      waitDuration: const Duration(milliseconds: 200),

      child: card,

    );

  }

}


