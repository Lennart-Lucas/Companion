import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';
class TrackerSuccessTrendChart extends StatelessWidget {
  const TrackerSuccessTrendChart({
    super.key,
    required this.weeklyRates,
  });

  final List<double> weeklyRates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rates = weeklyRates.length >= 8
        ? weeklyRates.sublist(weeklyRates.length - 8)
        : weeklyRates;

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '8-week trend',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Weekly success rate',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: rates.isEmpty
                ? Center(
                    child: Text(
                      'No history yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < rates.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: i == 0 ? 0 : 4,
                              right: i == rates.length - 1 ? 0 : 4,
                            ),
                            child: _TrendBar(rate: rates[i]),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clamped = rate.clamp(0.0, 1.0);
    final barColor = trackerStrengthBarColor(clamped);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${(clamped * 100).round()}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.55),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 80,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 80 * (clamped == 0 ? 0.04 : clamped),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
