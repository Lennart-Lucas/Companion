import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';

/// Handles auth side-effects and loading overlay for [MaterialApp.router].
class AuthScope extends StatelessWidget {
  const AuthScope({super.key, required this.child});

  final Widget? child;

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
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}
