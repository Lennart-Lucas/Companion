import 'package:flutter/material.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/widgets/media_title_poster_thumbnail.dart';
import 'package:frontend/features/inputs/widgets/media_title_star_rating.dart';
import 'package:frontend/features/inputs/widgets/media_title_watch_status_chip.dart';
import 'package:frontend/features/inputs/widgets/actor_filmography_sheet.dart';
import 'package:frontend/features/inputs/services/media_title_list_actions.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

class MediaTitleDetailSidebar extends StatelessWidget {
  const MediaTitleDetailSidebar({
    super.key,
    required this.mediaTitle,
    required this.isTv,
    this.episodeCount,
    this.episodesSeen,
    required this.onWatchStatusChanged,
    required this.onUserRatingChanged,
    this.actions,
    this.compact = false,
  });

  static const width = 320.0;

  final MediaTitle mediaTitle;
  final bool isTv;
  final int? episodeCount;
  final int? episodesSeen;
  final ValueChanged<String> onWatchStatusChanged;
  final ValueChanged<double?> onUserRatingChanged;
  final MediaTitleListTileActions? actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mediaTypeIcon = resolveTaskCategoryIconData(
      iconName: 'Clapperboard',
      defaultIconName: 'Clapperboard',
      materialFallback: Icons.movie_outlined,
    );

    return SizedBox(
      width: compact ? null : width,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TrackerRowPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: MediaTitlePosterThumbnail(
                  posterUrl: mediaTitle.posterUrl,
                  width: 160,
                  height: 240,
                  borderRadius: 12,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                mediaTitle.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: CompanionFormStyles.taskListChipGap,
                runSpacing: CompanionFormStyles.taskListChipGap,
                children: [
                  MediaTitleWatchStatusChip(
                    value: mediaTitle.watchStatus,
                    onChanged: onWatchStatusChanged,
                  ),
                  TaskMetaChip(
                    label: mediaTypeLabel(mediaTitle.mediaType),
                    tintColor: scheme.primary,
                    bordered: false,
                    leading: Icon(
                      mediaTypeIcon,
                      size: 14,
                      color: scheme.primary,
                    ),
                  ),
                  for (final genre in mediaTitle.genres.take(3))
                    TaskMetaChip(
                      label: genre,
                      neutral: true,
                      bordered: false,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Your rating',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: MediaTitleStarRating(
                  value: mediaTitle.userRating,
                  onChanged: onUserRatingChanged,
                ),
              ),
              const SizedBox(height: 16),
              _MetadataList(
                mediaTitle: mediaTitle,
                isTv: isTv,
                episodeCount: episodeCount,
                episodesSeen: episodesSeen,
              ),
              if (mediaTitle.cast.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cast',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final member in mediaTitle.cast.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CastMemberRow(
                      member: member,
                      actions: actions,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CastMemberRow extends StatelessWidget {
  const _CastMemberRow({
    required this.member,
    this.actions,
  });

  final MediaTitleCastMember member;
  final MediaTitleListTileActions? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => showActorFilmographySheet(
            context,
            member: member,
            actions: actions,
          ),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              member.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
        ),
        if (member.character != null && member.character!.isNotEmpty)
          Text(
            'as ${member.character}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
      ],
    );
  }
}

class _MetadataList extends StatelessWidget {
  const _MetadataList({
    required this.mediaTitle,
    required this.isTv,
    this.episodeCount,
    this.episodesSeen,
  });

  final MediaTitle mediaTitle;
  final bool isTv;
  final int? episodeCount;
  final int? episodesSeen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.55),
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    final rows = <(String, String)>[
      if (mediaTitle.year != null) ('Year', '${mediaTitle.year}'),
      if (mediaTitle.runtimeMinutes != null)
        ('Runtime', '${mediaTitle.runtimeMinutes} min'),
      if (mediaTitle.rating != null)
        ('IMDb rating', mediaTitle.rating!.toStringAsFixed(1)),
      if (isTv && episodeCount != null && episodesSeen != null)
        ('Episodes seen', '$episodesSeen / $episodeCount'),
      if (isTv && episodeCount != null && episodesSeen == null)
        ('Episodes', '$episodeCount'),
    ];

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(rows[i].$1, style: labelStyle)),
              Text(rows[i].$2, style: valueStyle),
            ],
          ),
        ],
      ],
    );
  }
}
