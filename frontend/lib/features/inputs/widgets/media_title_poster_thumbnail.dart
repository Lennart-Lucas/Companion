import 'package:flutter/material.dart';

class MediaTitlePosterThumbnail extends StatelessWidget {
  const MediaTitlePosterThumbnail({
    super.key,
    required this.posterUrl,
    this.width = 48,
    this.height = 72,
    this.borderRadius = 8,
  });

  final String? posterUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = posterUrl?.trim();
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.movie_outlined,
        color: scheme.onSurfaceVariant,
      ),
    );

    if (trimmed == null || trimmed.isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        trimmed,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}
