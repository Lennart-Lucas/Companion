import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/auth/shared_preferences_token_storage.dart';
import 'package:frontend/core/routing/auth_bloc_listenable.dart';
import 'package:frontend/core/routing/companion_router.dart';
import 'package:frontend/core/routing/companion_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initializes [CompanionAnvilApp] once for widget tests that depend on
/// [CompanionAnvilApp.instance] (local cache, api client, etc.).
Future<void> initTestCompanionAnvilApp() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await SharedPreferencesTokenStorage.init();
  await CompanionAnvilApp.init(
    httpClientOverride: MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
      responses: {
        'GET:/auth/me': (request) async => HttpResponse(
              statusCode: 200,
              headers: const {'Content-Type': 'application/json'},
              jsonBody: const {},
            ),
      },
    ),
  );
}

Future<void> disposeTestCompanionAnvilApp() async {
  await CompanionAnvilApp.instance.dispose();
}

/// Pumps [child] inside a themed [MaterialApp] with optional bloc providers.
Future<void> pumpCompanionWidget(
  WidgetTester tester, {
  required Widget child,
  List<BlocProvider> providers = const [],
}) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: providers,
      child: MaterialApp(
        theme: theHubTheme,
        home: child,
      ),
    ),
  );
}

/// Bounded pump loop until [finder] matches or [maxPumps] is exhausted.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 50,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

/// Pumps [router] with optional bloc providers.
Future<void> pumpWithGoRouter(
  WidgetTester tester, {
  required GoRouter router,
  List<BlocProvider> providers = const [],
}) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: providers,
      child: MaterialApp.router(
        theme: theHubTheme,
        routerConfig: router,
      ),
    ),
  );
}

/// Waits until [authBloc] reaches a state matching [predicate].
Future<AuthState> waitForAuthState(
  AuthBloc authBloc, {
  required bool Function(AuthState state) predicate,
  Duration timeout = const Duration(seconds: 10),
}) {
  if (predicate(authBloc.state)) {
    return Future.value(authBloc.state);
  }
  return authBloc.stream
      .firstWhere(predicate)
      .timeout(timeout, onTimeout: () => authBloc.state);
}

/// Clears tokens and waits for an unauthenticated session.
Future<void> seedUnauthenticatedSession(AuthBloc authBloc) async {
  authBloc.add(const LogoutRequested());
  await waitForAuthState(authBloc, predicate: (s) => s is Unauthenticated);
}

/// Stores mock tokens and waits for an authenticated session.
Future<void> seedAuthenticatedSession({
  required AuthBloc authBloc,
  required AuthTokenProviderService tokenProvider,
}) async {
  await tokenProvider.setTokens(
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
  );
  authBloc.add(const AppStarted());
  final state = await waitForAuthState(
    authBloc,
    predicate: (s) =>
        s is Authenticated || (s is Unauthenticated && s.hasError),
  );
  if (state is! Authenticated) {
    fail('Expected authenticated session, got $state');
  }
}

/// Builds a test [GoRouter] with auth redirect support.
GoRouter buildTestCompanionRouter({
  required AuthBloc authBloc,
  String? initialLocation,
  List<RouteBase>? routes,
}) {
  return buildCompanionRouter(
    authBloc: authBloc,
    refreshListenable: AuthBlocListenable(authBloc),
    initialLocation: initialLocation ?? CompanionRoutes.productivityOverview,
  );
}

/// Pumps the full companion router for integration-style widget tests.
Future<void> pumpCompanionRouter(
  WidgetTester tester, {
  required AuthBloc authBloc,
  List<BlocProvider> providers = const [],
}) async {
  final router = buildTestCompanionRouter(authBloc: authBloc);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        ...providers,
      ],
      child: MaterialApp.router(
        theme: theHubTheme,
        routerConfig: router,
      ),
    ),
  );
}
