import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/offline_banner.dart';
import 'package:frontend/core/offline/offline_lifecycle_listener.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/core/theme/app_theme_controller.dart';
import 'package:frontend/features/auth/widgets/auth_scope.dart';

class CompanionApp extends StatefulWidget {
  const CompanionApp({super.key});

  @override
  State<CompanionApp> createState() => _CompanionAppState();
}

class _CompanionAppState extends State<CompanionApp> {
  @override
  void initState() {
    super.initState();
    CompanionRouterHost.init(CompanionAnvilApp.instance.authBloc);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppThemeController.instance;
    final router = CompanionRouterHost.instance.router;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(
          value: CompanionAnvilApp.instance.authBloc,
        ),
        BlocProvider<RecordBloc>.value(
          value: CompanionAnvilApp.instance.recordBloc,
        ),
      ],
      child: ListenableBuilder(
        listenable: themeController,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'Companion',
            debugShowCheckedModeBanner: false,
            theme: themeController.theme,
            themeMode: ThemeMode.dark,
            scrollBehavior: AnvilNoScrollbarScrollBehavior(),
            routerConfig: router,
            builder: (context, child) {
              return OfflineLifecycleListener(
                child: OfflineBannerHost(
                  child: AuthScope(child: child),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
