import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Provides a minimal [AnvilFormBloc] so [AnvilTextField] can be used on auth screens.
class AuthFormScope extends StatelessWidget {
  const AuthFormScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final config = AnvilFormConfig(
      formKey: 'auth_form',
      steps: const ['main'],
      pages: {
        'main': AnvilFormPage(
          builder: (context, state) => const SizedBox.shrink(),
        ),
      },
      initialValues: const {},
      submitHandler: CallbackSubmitHandler(
        onSubmit: (_) async => const FormSubmitResult.success(),
      ),
    );

    return BlocProvider(
      create: (_) => AnvilFormBloc(config: config)
        ..add(const AnvilFormInitialized()),
      child: child,
    );
  }
}
