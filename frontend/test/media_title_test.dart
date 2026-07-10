import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/inputs/models/media_title.dart';

void main() {
  test('normalizeImdbIdInput accepts valid ids', () {
    expect(normalizeImdbIdInput('tt1375666'), 'tt1375666');
    expect(normalizeImdbIdInput(' TT01375212 '), 'tt01375212');
  });

  test('normalizeImdbIdInput rejects invalid ids', () {
    expect(normalizeImdbIdInput('inception'), isNull);
    expect(normalizeImdbIdInput('tt123'), isNull);
  });

  test('MediaTitle.fromJson maps saved API payload', () {
    final title = MediaTitle.fromJson({
      'id': 3,
      'name': 'Inception',
      'imdb_id': 'tt1375666',
      'media_type': 'movie',
      'year': 2010,
      'poster_url': 'https://example.com/inception.jpg',
      'imdb_url': 'https://www.imdb.com/title/tt1375666/',
      'rating': 8.8,
      'vote_count': 2500000,
      'genres': ['Action', 'Sci-Fi'],
      'runtime_minutes': 148,
      'cast': [
        {'name': 'Leonardo DiCaprio', 'character': 'Cobb'},
      ],
    });

    expect(title.name, 'Inception');
    expect(title.imdbId, 'tt1375666');
    expect(title.genres, ['Action', 'Sci-Fi']);
    expect(title.cast.first.name, 'Leonardo DiCaprio');
  });
}
