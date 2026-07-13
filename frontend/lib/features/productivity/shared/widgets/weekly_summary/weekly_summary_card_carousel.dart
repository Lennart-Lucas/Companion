import 'package:flutter/material.dart';

class WeeklySummaryCardCarousel extends StatelessWidget {
  const WeeklySummaryCardCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.cardWidth = 280,
    this.cardHeight = 220,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(width: cardWidth, child: itemBuilder(context, index));
        },
      ),
    );
  }
}
