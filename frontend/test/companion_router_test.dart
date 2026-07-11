import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/routing/companion_routes.dart';

void main() {
  group('CompanionRoutes', () {
    test('maps shell paths to menu keys', () {
      expect(
        CompanionRoutes.menuKeyForLocation('/productivity/goals/abc123'),
        'goals',
      );
      expect(
        CompanionRoutes.menuKeyForLocation('/inputs/movies-tv/title-1'),
        'movies-tv',
      );
      expect(
        CompanionRoutes.menuKeyForLocation('/settings/ui'),
        'settings-ui',
      );
    });

    test('maps menu keys to branch indices', () {
      expect(CompanionRoutes.shellBranchForMenuKey('tasks'), 5);
      expect(CompanionRoutes.shellBranchForMenuKey('movies-tv'), 6);
      expect(
        CompanionRoutes.shellPathForMenuKey('trackers'),
        CompanionRoutes.productivityTrackers,
      );
    });

    test('builds entity CRUD paths', () {
      expect(CompanionRoutes.goalDetail('g1'), '/productivity/goals/g1');
      expect(CompanionRoutes.goalEdit('g1'), '/productivity/goals/g1/edit');
      expect(
        CompanionRoutes.projectTaskCreate('p1'),
        '/productivity/projects/p1/tasks/new',
      );
      expect(
        CompanionRoutes.taskTodayBucket('overdue'),
        '/productivity/tasks/today/overdue',
      );
    });

    test('detects auth paths', () {
      expect(CompanionRoutes.isAuthPath('/login'), isTrue);
      expect(CompanionRoutes.isAuthPath('/register'), isTrue);
      expect(CompanionRoutes.isAuthPath('/productivity/goals'), isFalse);
    });
  });
}
