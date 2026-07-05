import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/offline_banner.dart';
import 'package:frontend/core/offline/offline_lifecycle_listener.dart';
import 'package:frontend/core/theme/app_theme_controller.dart';
import 'package:frontend/features/auth/widgets/auth_gate.dart';

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = CompanionAnvilApp.instance;
    final themeController = AppThemeController.instance;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: app.authBloc),
        BlocProvider<RecordBloc>.value(value: app.recordBloc),
      ],
      child: ListenableBuilder(
        listenable: themeController,
        builder: (context, _) {
          return MaterialApp(
            title: 'Companion',
            debugShowCheckedModeBanner: false,
            theme: themeController.theme,
            themeMode: ThemeMode.dark,
            scrollBehavior: AnvilNoScrollbarScrollBehavior(),
            home: const OfflineLifecycleListener(
              child: OfflineBannerHost(child: AuthGate()),
            ),
          );
        },
      ),
    );
  }
}
