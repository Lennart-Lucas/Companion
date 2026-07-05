import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/auth/pages/login_page.dart';
import 'package:frontend/shell/app_shell.dart';

/// Routes between login and the main app based on [AuthBloc] state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous is Authenticated && current is Unauthenticated,
      listener: (context, state) {
        CompanionAnvilApp.instance.syncService.clearLocalData();
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthUnknown || state is AuthLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (state is Authenticated) {
            return const AppShell();
          }
          return const LoginPage();
        },
      ),
    );
  }
}
