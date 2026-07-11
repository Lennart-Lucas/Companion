import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/events/forms/event_form_config.dart';

void main() {
  testWidgets('EventCreatePage shows event wizard', (WidgetTester tester) async {
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
          home: Scaffold(
            appBar: AppBar(title: const Text('New event')),
            body: AnvilFormWizard(
              config: buildEventFormConfig(
                app.recordBloc,
                apiClient: app.apiClient,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New event'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('When'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    app.dispose();
  });

  test('buildEventFormConfig uses wizard steps for edit', () {
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
    );
    final api = ApiClientService(mockHttp);
    final repo = HttpRecordRepositoryService(api);
    final coordinator =
        RecordCoordinatorService(buildCompanionRecordRegistry(), repo);
    final recordBloc = RecordBloc(coordinator);

    final config = buildEventFormConfig(
      recordBloc,
      apiClient: api,
      recordId: '42',
    );

    expect(config.steps, ['main', 'schedule']);
    expect(config.submitHandler.canHydrate, isTrue);

    recordBloc.close();
  });
}
