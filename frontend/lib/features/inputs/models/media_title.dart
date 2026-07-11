import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/productivity_record.dart';

abstract final class MediaWatchStatus {
  static const planToWatch = 'plan_to_watch';
  static const watching = 'watching';
  static const completed = 'completed';
  static const onHold = 'on_hold';
  static const dropped = 'dropped';

  static const all = [
    planToWatch,
    watching,
    completed,
    onHold,
    dropped,
  ];
}

class MediaTitle extends ProductivityRecord {
  @override
  final RecordId id;
  @override
  RecordType get recordType => 'media_titles';
  @override
  final String name;

  final String imdbId;
  final String? mediaType;
  final int? year;
  final String? description;
  final String? posterUrl;
  final String imdbUrl;
  final double? rating;
  final int? voteCount;
  final List<String> genres;
  final int? runtimeMinutes;
  final List<MediaTitleCastMember> cast;
  final String watchStatus;
  final double? userRating;
  final String? notes;

  MediaTitle({
    required this.id,
    required this.name,
    required this.imdbId,
    this.mediaType,
    this.year,
    this.description,
    this.posterUrl,
    required this.imdbUrl,
    this.rating,
    this.voteCount,
    this.genres = const [],
    this.runtimeMinutes,
    this.cast = const [],
    this.watchStatus = MediaWatchStatus.planToWatch,
    this.userRating,
    this.notes,
  });

  static int? intFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? doubleFromJson(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _intFromJson(dynamic value) => intFromJson(value);

  static double? _doubleFromJson(dynamic value) => doubleFromJson(value);

  static List<String> _genresFromJson(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is String && entry.trim().isNotEmpty) entry.trim(),
    ];
  }

  static List<MediaTitleCastMember> _castFromJson(dynamic value) {
    if (value is! List) return const [];
    final cast = <MediaTitleCastMember>[];
    for (final entry in value) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final actorName = map['name'] as String?;
      if (actorName == null || actorName.trim().isEmpty) continue;
      cast.add(
        MediaTitleCastMember(
          name: actorName.trim(),
          character: (map['character'] as String?)?.trim(),
          imdbNameId: (map['imdb_name_id'] as String?)?.trim(),
        ),
      );
    }
    return cast;
  }

  factory MediaTitle.fromJson(Map<String, dynamic> json) {
    final data = ProductivityRecord.unwrapJson(json);
    return MediaTitle(
      id: ProductivityRecord.idFromJson(data),
      name: ProductivityRecord.nameFromJson(data),
      imdbId: data['imdb_id'] as String? ?? '',
      mediaType: data['media_type'] as String?,
      year: _intFromJson(data['year']),
      description: data['description'] as String?,
      posterUrl: data['poster_url'] as String?,
      imdbUrl: data['imdb_url'] as String? ?? '',
      rating: _doubleFromJson(data['rating']),
      voteCount: _intFromJson(data['vote_count']),
      genres: _genresFromJson(data['genres']),
      runtimeMinutes: _intFromJson(data['runtime_minutes']),
      cast: _castFromJson(data['cast']),
      watchStatus:
          data['watch_status'] as String? ?? MediaWatchStatus.planToWatch,
      userRating: _doubleFromJson(data['user_rating']),
      notes: data['notes'] as String?,
    );
  }

  MediaTitle copyWith({
    String? watchStatus,
    double? userRating,
    String? notes,
    bool clearUserRating = false,
    bool clearNotes = false,
  }) {
    return MediaTitle(
      id: id,
      name: name,
      imdbId: imdbId,
      mediaType: mediaType,
      year: year,
      description: description,
      posterUrl: posterUrl,
      imdbUrl: imdbUrl,
      rating: rating,
      voteCount: voteCount,
      genres: genres,
      runtimeMinutes: runtimeMinutes,
      cast: cast,
      watchStatus: watchStatus ?? this.watchStatus,
      userRating: clearUserRating ? null : (userRating ?? this.userRating),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imdb_id': imdbId,
      if (mediaType != null) 'media_type': mediaType,
      if (year != null) 'year': year,
      if (description != null) 'description': description,
      if (posterUrl != null) 'poster_url': posterUrl,
      'imdb_url': imdbUrl,
      if (rating != null) 'rating': rating,
      if (voteCount != null) 'vote_count': voteCount,
      if (genres.isNotEmpty) 'genres': genres,
      if (runtimeMinutes != null) 'runtime_minutes': runtimeMinutes,
      if (cast.isNotEmpty)
        'cast': [
          for (final member in cast)
            {
              'name': member.name,
              if (member.character != null) 'character': member.character,
              if (member.imdbNameId != null) 'imdb_name_id': member.imdbNameId,
            },
        ],
      'watch_status': watchStatus,
      if (userRating != null) 'user_rating': userRating,
      if (notes != null) 'notes': notes,
    };
  }
}

class MediaTitleCastMember {
  const MediaTitleCastMember({
    required this.name,
    this.character,
    this.imdbNameId,
  });

  final String name;
  final String? character;
  final String? imdbNameId;
}

class ImdbTitleSummary {
  const ImdbTitleSummary({
    required this.imdbId,
    required this.name,
    this.mediaType,
    this.year,
    this.posterUrl,
  });

  final String imdbId;
  final String name;
  final String? mediaType;
  final int? year;
  final String? posterUrl;

  factory ImdbTitleSummary.fromJson(Map<String, dynamic> json) {
    return ImdbTitleSummary(
      imdbId: json['imdb_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mediaType: json['media_type'] as String?,
      year: MediaTitle._intFromJson(json['year']),
      posterUrl: json['poster_url'] as String?,
    );
  }
}

class ImdbTitleDetail extends ImdbTitleSummary {
  const ImdbTitleDetail({
    required super.imdbId,
    required super.name,
    super.mediaType,
    super.year,
    super.posterUrl,
    this.description,
    required this.imdbUrl,
    this.rating,
    this.voteCount,
    this.genres = const [],
    this.runtimeMinutes,
    this.cast = const [],
  });

  final String? description;
  final String imdbUrl;
  final double? rating;
  final int? voteCount;
  final List<String> genres;
  final int? runtimeMinutes;
  final List<MediaTitleCastMember> cast;

  factory ImdbTitleDetail.fromJson(Map<String, dynamic> json) {
    return ImdbTitleDetail(
      imdbId: json['imdb_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mediaType: json['media_type'] as String?,
      year: MediaTitle._intFromJson(json['year']),
      posterUrl: json['poster_url'] as String?,
      description: json['description'] as String?,
      imdbUrl: json['imdb_url'] as String? ?? '',
      rating: MediaTitle._doubleFromJson(json['rating']),
      voteCount: MediaTitle._intFromJson(json['vote_count']),
      genres: MediaTitle._genresFromJson(json['genres']),
      runtimeMinutes: MediaTitle._intFromJson(json['runtime_minutes']),
      cast: MediaTitle._castFromJson(json['cast']),
    );
  }
}

final RegExp imdbIdPattern = RegExp(r'^tt\d{7,}$', caseSensitive: false);

String? normalizeImdbIdInput(String value) {
  final trimmed = value.trim();
  if (!imdbIdPattern.hasMatch(trimmed)) return null;
  return trimmed.toLowerCase();
}

String mediaTypeLabel(String? mediaType) {
  final value = mediaType?.trim();
  if (value == null || value.isEmpty) return 'Title';
  switch (value.toLowerCase()) {
    case 'movie':
      return 'Movie';
    case 'tvseries':
    case 'tv_series':
      return 'TV Series';
    case 'tvminiseries':
    case 'tv_mini_series':
      return 'Mini Series';
    case 'tvmovie':
    case 'tv_movie':
      return 'TV Movie';
    case 'short':
      return 'Short';
    case 'video':
      return 'Video';
    default:
      return value
          .replaceAll('_', ' ')
          .replaceAllMapped(
            RegExp(r'\b[a-z]'),
            (match) => match.group(0)!.toUpperCase(),
          );
  }
}

bool isTvMediaType(String? mediaType) {
  if (mediaType == null || mediaType.trim().isEmpty) return false;
  final normalized = mediaType.trim().toLowerCase().replaceAll('_', '');
  return normalized == 'tvseries' ||
      normalized == 'tvminiseries' ||
      normalized == 'tvspecial';
}

String watchStatusLabel(String status) {
  switch (status) {
    case MediaWatchStatus.planToWatch:
      return 'Plan to watch';
    case MediaWatchStatus.watching:
      return 'Watching';
    case MediaWatchStatus.completed:
      return 'Completed';
    case MediaWatchStatus.onHold:
      return 'On hold';
    case MediaWatchStatus.dropped:
      return 'Dropped';
    default:
      return status.replaceAll('_', ' ');
  }
}
