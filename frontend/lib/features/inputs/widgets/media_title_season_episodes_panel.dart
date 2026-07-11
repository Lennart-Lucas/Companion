import 'package:flutter/material.dart';
import 'package:frontend/features/inputs/models/media_watch_entry.dart';
import 'package:frontend/features/inputs/services/media_watch_progress.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class MediaTitleSeasonEpisodesPanel extends StatefulWidget {
  const MediaTitleSeasonEpisodesPanel({
    super.key,
    required this.episodes,
    required this.watchEntries,
    this.nextEpisode,
    this.onToggleEpisode,
    this.onToggleMovie,
    this.toggleEnabled = true,
    this.isMovie = false,
  });

  final List<ImdbEpisodeSummary> episodes;
  final List<MediaWatchEntry> watchEntries;
  final ImdbEpisodeSummary? nextEpisode;
  final void Function(ImdbEpisodeSummary episode, bool markWatched)?
      onToggleEpisode;
  final void Function(bool markWatched)? onToggleMovie;
  final bool toggleEnabled;
  final bool isMovie;

  @override
  State<MediaTitleSeasonEpisodesPanel> createState() =>
      _MediaTitleSeasonEpisodesPanelState();
}

class _MediaTitleSeasonEpisodesPanelState
    extends State<MediaTitleSeasonEpisodesPanel> {
  final Set<int> _expandedSeasons = {};

  @override
  void initState() {
    super.initState();
    _syncDefaultExpansion();
  }

  @override
  void didUpdateWidget(covariant MediaTitleSeasonEpisodesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodes != widget.episodes ||
        oldWidget.watchEntries != widget.watchEntries) {
      _syncDefaultExpansion();
    }
  }

  void _syncDefaultExpansion() {
    if (widget.isMovie || widget.episodes.isEmpty) return;
    final progress = computeSeasonProgress(widget.episodes, widget.watchEntries);
    final defaultSeason = progress
            .where((season) => season.isInProgress)
            .map((season) => season.seasonNumber)
            .firstOrNull ??
        progress
            .where((season) => !season.isComplete)
            .map((season) => season.seasonNumber)
            .firstOrNull ??
        progress.first.seasonNumber;
    _expandedSeasons
      ..clear()
      ..add(defaultSeason);
  }

  Map<String, MediaWatchEntry> get _watchedEntries {
    return {
      for (final entry in widget.watchEntries)
        if (entry.seasonNumber != null && entry.episodeNumber != null)
          '${entry.seasonNumber}:${entry.episodeNumber}': entry,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (widget.isMovie) {
      return _buildMoviePanel(theme, scheme);
    }

    if (widget.episodes.isEmpty) {
      return TrackerRowPanel(
        child: Text(
          'Episode list unavailable',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      );
    }

    final seasons = computeSeasonProgress(widget.episodes, widget.watchEntries);
    final grouped = groupEpisodesBySeason(widget.episodes);

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Episodes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final season in seasons)
            _SeasonExpansion(
              progress: season,
              episodes: grouped[season.seasonNumber] ?? const [],
              expanded: _expandedSeasons.contains(season.seasonNumber),
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedSeasons.add(season.seasonNumber);
                  } else {
                    _expandedSeasons.remove(season.seasonNumber);
                  }
                });
              },
              watchedEntries: _watchedEntries,
              nextEpisode: widget.nextEpisode,
              onToggleEpisode: widget.onToggleEpisode,
              toggleEnabled: widget.toggleEnabled,
            ),
        ],
      ),
    );
  }

  Widget _buildMoviePanel(ThemeData theme, ColorScheme scheme) {
    final entry = widget.watchEntries.cast<MediaWatchEntry?>().firstWhere(
          (e) => e?.seasonNumber == null && e?.episodeNumber == null,
          orElse: () => null,
        );
    final isWatched = entry != null;

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Watch progress',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _EpisodeRow(
            label: isWatched ? 'Watched' : 'Not watched yet',
            subtitle: isWatched ? _formatWatchedAt(entry.watchedAt) : null,
            isWatched: isWatched,
            isNext: !isWatched,
            onToggle: widget.onToggleMovie == null
                ? null
                : () => widget.onToggleMovie!(!isWatched),
            toggleEnabled: widget.toggleEnabled,
          ),
        ],
      ),
    );
  }

  static String _formatWatchedAt(DateTime watchedAt) {
    final local = watchedAt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return 'Watched $y-$m-$d';
  }
}

class _SeasonExpansion extends StatelessWidget {
  const _SeasonExpansion({
    required this.progress,
    required this.episodes,
    required this.expanded,
    required this.onExpansionChanged,
    required this.watchedEntries,
    required this.nextEpisode,
    required this.onToggleEpisode,
    required this.toggleEnabled,
  });

  final MediaSeasonProgress progress;
  final List<ImdbEpisodeSummary> episodes;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final Map<String, MediaWatchEntry> watchedEntries;
  final ImdbEpisodeSummary? nextEpisode;
  final void Function(ImdbEpisodeSummary episode, bool markWatched)?
      onToggleEpisode;
  final bool toggleEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 4, bottom: 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Season ${progress.seasonNumber} · ${progress.label}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: progress.isComplete
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        children: [
          for (final episode in episodes)
            () {
              final key = '${episode.seasonNumber}:${episode.episodeNumber}';
              final entry = watchedEntries[key];
              final isWatched = entry != null;
              final isNext = nextEpisode != null &&
                  nextEpisode!.seasonNumber == episode.seasonNumber &&
                  nextEpisode!.episodeNumber == episode.episodeNumber &&
                  !isWatched;
              return _EpisodeRow(
                label:
                    'E${episode.episodeNumber} · ${episode.title}',
                subtitle: isWatched
                    ? _MediaTitleSeasonEpisodesPanelState._formatWatchedAt(
                        entry.watchedAt,
                      )
                    : null,
                isWatched: isWatched,
                isNext: isNext,
                onToggle: onToggleEpisode == null
                    ? null
                    : () => onToggleEpisode!(episode, !isWatched),
                toggleEnabled: toggleEnabled,
              );
            }(),
        ],
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.label,
    this.subtitle,
    required this.isWatched,
    required this.isNext,
    this.onToggle,
    this.toggleEnabled = true,
  });

  final String label;
  final String? subtitle;
  final bool isWatched;
  final bool isNext;
  final VoidCallback? onToggle;
  final bool toggleEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = isNext
        ? scheme.primaryContainer.withValues(alpha: 0.45)
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: isWatched ? 'Mark unwatched' : 'Mark watched',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            onPressed: toggleEnabled ? onToggle : null,
            icon: Icon(
              isWatched ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: isWatched
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isNext ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isNext)
                  Text(
                    'Next up',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
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
