import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/foundation.dart';

/// Exposes [AuthBloc] state changes as a [Listenable] for [GoRouter.refreshListenable].
class AuthBlocListenable extends ChangeNotifier {
  AuthBlocListenable(this._authBloc) {
    _subscription = _authBloc.stream.listen((_) => notifyListeners());
  }

  final AuthBloc _authBloc;
  late final StreamSubscription<AuthState> _subscription;

  AuthState get state => _authBloc.state;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
