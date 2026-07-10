import 'package:flutter/material.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/goal_stats.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

enum GoalHealthBand {
  strong,
  steady,
  fragile,
  atRisk,
}

class GoalHealthOverview {
  const GoalHealthOverview({
    required this.score,
    required this.band,
    required this.progressScore,
    required this.linkedTrackerCount,
    required this.summary,
    this.trackerSupportScore,
    this.averageTrackerStrength,
    this.averageTrackerConsistency,
  });

  final double score;
  final GoalHealthBand band;
  final double progressScore;
  final double? trackerSupportScore;
  final int linkedTrackerCount;
  final double? averageTrackerStrength;
  final double? averageTrackerConsistency;
  final String summary;
}

double computeGoalProgressHealthScore(GoalStats stats) {
  var score = stats.progressPercent;
  score += switch (stats.pace) {
    GoalPace.ahead => 8.0,
    GoalPace.onTrack => 0.0,
    GoalPace.behind => -12.0,
    GoalPace.unknown => 0.0,
  };
  return score.clamp(0.0, 100.0).toDouble();
}

double computeSingleTrackerSupportScore(TrackerStats stats) {
  return (stats.habitStrength * 0.65 + stats.consistency * 100 * 0.35)
      .clamp(0.0, 100.0)
      .toDouble();
}

GoalHealthBand goalHealthBandForScore(double score) {
  if (score >= 75) return GoalHealthBand.strong;
  if (score >= 50) return GoalHealthBand.steady;
  if (score >= 25) return GoalHealthBand.fragile;
  return GoalHealthBand.atRisk;
}

String formatGoalHealthBand(GoalHealthBand band) => switch (band) {
      GoalHealthBand.strong => 'Strong',
      GoalHealthBand.steady => 'Steady',
      GoalHealthBand.fragile => 'Fragile',
      GoalHealthBand.atRisk => 'At risk',
    };

Color goalHealthBandColor(GoalHealthBand band) => switch (band) {
      GoalHealthBand.strong => trackerStrengthHighColor,
      GoalHealthBand.steady => trackerStrengthMidColor,
      GoalHealthBand.fragile => trackerStrengthLowColor,
      GoalHealthBand.atRisk => companionUrgentColor,
    };

String buildGoalHealthSummary({
  required GoalStats stats,
  required double progressScore,
  required double? trackerSupportScore,
  required int linkedTrackerCount,
}) {
  final paceLabel = switch (stats.pace) {
    GoalPace.ahead => 'Ahead of schedule',
    GoalPace.onTrack => 'On track',
    GoalPace.behind => 'Behind schedule',
    GoalPace.unknown => 'Progress ${progressScore.round()}%',
  };

  if (linkedTrackerCount == 0) {
    return '$paceLabel · no supporting trackers linked';
  }

  final trackerLabel = linkedTrackerCount == 1
      ? '1 supporting tracker'
      : '$linkedTrackerCount supporting trackers';

  if (trackerSupportScore == null) {
    return '$paceLabel · $trackerLabel';
  }

  final supportLabel = switch (goalHealthBandForScore(trackerSupportScore)) {
    GoalHealthBand.strong => 'strong habit support',
    GoalHealthBand.steady => 'steady habit support',
    GoalHealthBand.fragile => 'fragile habit support',
    GoalHealthBand.atRisk => 'weak habit support',
  };

  return '$paceLabel · $supportLabel from $trackerLabel';
}

GoalHealthOverview computeGoalHealth({
  required GoalStats stats,
  required List<TrackerStats> trackerStats,
}) {
  final progressScore = computeGoalProgressHealthScore(stats);
  final linkedTrackerCount = trackerStats.length;

  double? trackerSupportScore;
  double? averageTrackerStrength;
  double? averageTrackerConsistency;

  if (trackerStats.isNotEmpty) {
    var strengthTotal = 0.0;
    var consistencyTotal = 0.0;
    var supportTotal = 0.0;
    for (final tracker in trackerStats) {
      strengthTotal += tracker.habitStrength;
      consistencyTotal += tracker.consistency;
      supportTotal += computeSingleTrackerSupportScore(tracker);
    }
    final count = trackerStats.length;
    averageTrackerStrength = strengthTotal / count;
    averageTrackerConsistency = consistencyTotal / count;
    trackerSupportScore = supportTotal / count;
  }

  final score = trackerSupportScore == null
      ? progressScore
      : (progressScore * 0.60 + trackerSupportScore * 0.40)
          .clamp(0.0, 100.0)
          .toDouble();

  final band = goalHealthBandForScore(score);

  return GoalHealthOverview(
    score: score,
    band: band,
    progressScore: progressScore,
    trackerSupportScore: trackerSupportScore,
    linkedTrackerCount: linkedTrackerCount,
    averageTrackerStrength: averageTrackerStrength,
    averageTrackerConsistency: averageTrackerConsistency,
    summary: buildGoalHealthSummary(
      stats: stats,
      progressScore: progressScore,
      trackerSupportScore: trackerSupportScore,
      linkedTrackerCount: linkedTrackerCount,
    ),
  );
}
