import 'package:flutter/widgets.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';

/// Triggers sync when the app returns to the foreground.
class OfflineLifecycleListener extends StatefulWidget {
  const OfflineLifecycleListener({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineLifecycleListener> createState() =>
      _OfflineLifecycleListenerState();
}

class _OfflineLifecycleListenerState extends State<OfflineLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      CompanionAnvilApp.instance.syncService.syncNow();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
