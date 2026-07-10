import 'package:flutter/material.dart';

class MediaTitleStarRating extends StatelessWidget {
  const MediaTitleStarRating({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filledColor = scheme.primary;
    final emptyColor = scheme.onSurface.withValues(alpha: 0.25);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          _StarButton(
            starIndex: star,
            value: value,
            filledColor: filledColor,
            emptyColor: emptyColor,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({
    required this.starIndex,
    required this.value,
    required this.filledColor,
    required this.emptyColor,
    required this.onChanged,
  });

  final int starIndex;
  final double? value;
  final Color filledColor;
  final Color emptyColor;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value ?? 0;
    final fullThreshold = starIndex.toDouble();
    final halfThreshold = starIndex - 0.5;
    final isFull = current >= fullThreshold;
    final isHalf = !isFull && current >= halfThreshold;

    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        final width = box?.size.width ?? 40;
        final localX = details.localPosition.dx;
        final next = localX <= width / 2 ? halfThreshold : fullThreshold;
        if (value != null && (value! - next).abs() < 0.01) {
          onChanged(null);
        } else {
          onChanged(next);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          isFull
              ? Icons.star
              : isHalf
                  ? Icons.star_half
                  : Icons.star_border,
          color: isFull || isHalf ? filledColor : emptyColor,
          size: 28,
        ),
      ),
    );
  }
}
