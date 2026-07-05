import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/offline/companion_connectivity_service.dart';

/// Debug-only panel shown on the login screen during development.
class LoginDebugPanel extends StatefulWidget {
  const LoginDebugPanel({super.key});

  @override
  State<LoginDebugPanel> createState() => _LoginDebugPanelState();
}

enum _ServerReachability { checking, reachable, unreachable }

class _LoginDebugPanelState extends State<LoginDebugPanel> {
  _ServerReachability _reachability = _ServerReachability.checking;
  Uri? _healthUri;
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    setState(() {
      _reachability = _ServerReachability.checking;
      _errorDetail = null;
    });
    final result = await CompanionConnectivityService.pingApi();
    if (!mounted) return;
    setState(() {
      _healthUri = result.healthUri;
      _errorDetail = result.error;
      _reachability = result.reachable
          ? _ServerReachability.reachable
          : _ServerReachability.unreachable;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (icon, label, color) = switch (_reachability) {
      _ServerReachability.checking => (
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          'Checking…',
          colorScheme.onSurfaceVariant,
        ),
      _ServerReachability.reachable => (
          Icon(Icons.check_circle, color: colorScheme.primary, size: 18),
          _errorDetail == null ? 'Server reachable' : 'Server responded',
          colorScheme.primary,
        ),
      _ServerReachability.unreachable => (
          Icon(Icons.error_outline, color: colorScheme.error, size: 18),
          'Server unreachable',
          colorScheme.error,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Debug',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _healthUri?.toString() ?? AppConfig.apiHealthUri.toString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_errorDetail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _errorDetail!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Recheck server',
                    onPressed: _reachability == _ServerReachability.checking
                        ? null
                        : _checkServer,
                    icon: const Icon(Icons.refresh, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
