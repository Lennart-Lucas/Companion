import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/http/companion_api_errors.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';


void main() {
  group('formatCompanionApiError', () {
    test('extracts FastAPI detail string', () {
      expect(
        formatCompanionApiError(
          statusCode: 422,
          body: {'detail': 'color must be a hex color in #RRGGBB format'},
          action: 'Create goals',
        ),
        'Create goals failed (HTTP 422): color must be a hex color in #RRGGBB format',
      );
    });

    test('extracts plain-text body', () {
      expect(
        formatCompanionApiError(
          statusCode: 500,
          body: 'Internal Server Error',
          action: 'Create goals',
        ),
        'Create goals failed (HTTP 500): Internal Server Error',
      );
    });

    test('falls back when body has no detail', () {
      expect(
        formatCompanionApiError(
          statusCode: 500,
          body: null,
          action: 'Create goals',
        ),
        'Create goals failed (HTTP 500)',
      );
    });
  });

  group('Project color hex normalization', () {
    test('normalizes 6-char string without hash', () {
      final project = Project.fromFormValues(
        {
          'name': 'Test',
          'status': 'active',
          'color': '22AA88',
        },
        id: '1',
      );
      expect(project.color, '#22AA88');
      expect(project.toJson()['color'], '#22AA88');
    });
  });
}
