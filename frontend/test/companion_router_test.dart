import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/routing/companion_routes.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';

import 'support/companion_test_helpers.dart';

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
      expect(
        CompanionRoutes.weeklySummary(DateTime(2026, 7, 6)),
        '/productivity/overview/week/2026-07-06',
      );
    });

    test('detects auth paths', () {
      expect(CompanionRoutes.isAuthPath('/login'), isTrue);
      expect(CompanionRoutes.isAuthPath('/register'), isTrue);
      expect(CompanionRoutes.isAuthPath('/productivity/goals'), isFalse);
    });
  });

  group('CompanionRouter redirect', () {
    testWidgets('redirects unauthenticated users to login', (tester) async {
      setupCompanionIcons();
      final app = AnvilApp(
        baseUrl: 'http://mock.local/api/v1',
        tokenStorage: InMemoryTokenStorage(),
        recordRegistry: buildCompanionRecordRegistry(),
        httpClient: MockHttpClientService(baseUrl: 'http://mock.local/api/v1'),
      );
      addTearDown(app.dispose);

      await seedUnauthenticatedSession(app.authBloc!);

      final router = buildTestCompanionRouter(
        authBloc: app.authBloc!,
        initialLocation: CompanionRoutes.productivityGoals,
      );

      await pumpWithGoRouter(
        tester,
        router: router,
        providers: [
          BlocProvider<AuthBloc>.value(value: app.authBloc!),
          BlocProvider<RecordBloc>.value(value: app.recordBloc),
        ],
      );
      await pumpUntilFound(tester, find.text('Sign in'));

      expect(find.text('Sign in'), findsWidgets);
    });
  });

  group('CompanionRouter authenticated shell', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      setupCompanionIcons();
      await initTestCompanionAnvilApp();
      await seedAuthenticatedSession(
        authBloc: CompanionAnvilApp.instance.authBloc,
        tokenProvider: CompanionAnvilApp.instance.tokenProvider,
      );
    });

    tearDownAll(() async {
      await disposeTestCompanionAnvilApp();
    });

    testWidgets('trackers route renders TrackersPage in shell branch 3', (
      tester,
    ) async {
      final authBloc = CompanionAnvilApp.instance.authBloc;
      final recordBloc = CompanionAnvilApp.instance.recordBloc;

      expect(
        CompanionRoutes.shellBranchForMenuKey('trackers'),
        CompanionRoutes.shellBranchTrackers,
      );

      final router = buildTestCompanionRouter(
        authBloc: authBloc,
        initialLocation: CompanionRoutes.productivityTrackers,
      );

      await pumpWithGoRouter(
        tester,
        router: router,
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<RecordBloc>.value(value: recordBloc),
        ],
      );
      await pumpUntilFound(tester, find.byTooltip('Add tracker'));

      expect(find.byTooltip('Add tracker'), findsOneWidget);
    });

    testWidgets('goal edit deep link renders GoalEditPage with injected goal', (
      tester,
    ) async {
      final authBloc = CompanionAnvilApp.instance.authBloc;
      final recordBloc = CompanionAnvilApp.instance.recordBloc;
      final goal = Goal(
        id: '7',
        name: 'Read 12 books',
        startDate: DateTime.utc(2026, 1, 1),
        target: 12,
        unit: 'books',
      );

      final router = buildTestCompanionRouter(authBloc: authBloc);

      await pumpWithGoRouter(
        tester,
        router: router,
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<RecordBloc>.value(value: recordBloc),
        ],
      );
      await tester.pump();

      router.push(CompanionRoutes.goalEdit('7'), extra: goal);
      await pumpUntilFound(tester, find.text('Edit goal'));

      expect(find.text('Edit goal'), findsOneWidget);
      expect(find.text('Save goal'), findsOneWidget);
    });
  });
}
