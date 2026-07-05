import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/auth/pages/login_page.dart';
import 'package:frontend/features/auth/widgets/auth_form_scope.dart';

void main() {
  testWidgets('LoginPage shows sign in', (WidgetTester tester) async {
    setupCompanionIcons();
    final app = AnvilApp(
      baseUrl: 'http://mock.local/api/v1',
      tokenStorage: InMemoryTokenStorage(),
      recordRegistry: buildCompanionRecordRegistry(),
      httpClient: MockHttpClientService(baseUrl: 'http://mock.local/api/v1'),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: app.authBloc!),
          BlocProvider<RecordBloc>.value(value: app.recordBloc),
        ],
        child: MaterialApp(
          theme: theHubTheme,
          home: const AuthFormScope(child: LoginPage()),
        ),
      ),
    );

    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(FilledButton), findsOneWidget);
    app.dispose();
  });
}
