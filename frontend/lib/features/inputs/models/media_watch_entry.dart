import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/productivity_record.dart';

class MediaWatchEntry extends ProductivityRecord {
  @override
  final RecordId id;
  @override
  RecordType get recordType => 'media_watch_entries';
  @override
  final String name;

  final String mediaTitleId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeImdbId;
  final String? episodeTitle;
  final DateTime watchedAt;

  MediaWatchEntry({
    required this.id,
    required this.mediaTitleId,
    required this.name,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeImdbId,
    this.episodeTitle,
    required this.watchedAt,
  });

  static DateTime _dateFromJson(dynamic value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }
    return DateTime.now().toUtc();
  }

  factory MediaWatchEntry.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    final season = data['season_number'];
    final episode = data['episode_number'];
    final title = data['episode_title'] as String?;
    final displayName = title?.trim().isNotEmpty == true
        ? title!.trim()
        : (season != null && episode != null ? 'S$season E$episode' : 'Watched');

    return MediaWatchEntry(
      id: ProductivityRecord.idFromJson(data),
      mediaTitleId: data['media_title_id']?.toString() ?? '',
      name: displayName,
      seasonNumber: season is int ? season : int.tryParse('$season'),
      episodeNumber: episode is int ? episode : int.tryParse('$episode'),
      episodeImdbId: data['episode_imdb_id'] as String?,
      episodeTitle: title,
      watchedAt: _dateFromJson(data['watched_at']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'media_title_id': mediaTitleId,
      'name': name,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (episodeImdbId != null) 'episode_imdb_id': episodeImdbId,
      if (episodeTitle != null) 'episode_title': episodeTitle,
      'watched_at': watchedAt.toUtc().toIso8601String(),
    };
  }

  bool matchesEpisode(int season, int episode) {
    return seasonNumber == season && episodeNumber == episode;
  }
}
