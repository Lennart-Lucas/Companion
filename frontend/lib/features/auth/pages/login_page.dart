import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/features/auth/widgets/auth_form_scope.dart';
import 'package:frontend/features/auth/widgets/login_debug_panel.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<AuthBloc>().add(
          LoginRequested(
            _emailController.text.trim(),
            _passwordController.text,
          ),
        );
  }

  String? _friendlyAuthError(String? error) {
    if (error == null) return null;
    final lower = error.toLowerCase();
    if (lower.contains('refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable')) {
      return 'Cannot reach the API at ${AppConfig.apiBaseUrl}. '
          'Start the backend (uvicorn on port 8000) and try again.';
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScope(
      child: Scaffold(
      body: AnvilBackgroundIcon(
        icon: Icons.lock_outline,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final loading = state is AuthLoading;
                  final error = state is Unauthenticated && state.hasError
                      ? _friendlyAuthError(state.errorMessage)
                      : null;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnvilCard(
                        body: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Sign in',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              AnvilTextField(
                                fieldKey: 'login_email',
                                label: 'Email',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                enabled: !loading,
                              ),
                              const SizedBox(height: 16),
                              AnvilTextField(
                                fieldKey: 'login_password',
                                label: 'Password',
                                controller: _passwordController,
                                obscureText: true,
                                enabled: !loading,
                              ),
                              if (error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  error,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: loading ? null : _submit,
                                child: loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Sign in'),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: loading
                                    ? null
                                    : () {
                                        CompanionNavigation.openRegister(
                                          context,
                                        );
                                      },
                                child: const Text('Create an account'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const LoginDebugPanel(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
