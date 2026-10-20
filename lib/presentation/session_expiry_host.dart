import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_unauthorized.dart';
import 'app_navigator.dart';
import 'providers/consent_provider.dart';
import 'providers/session_provider.dart';
import 'screens/auth_screen.dart';

/// Ouve o 401 autenticado, apaga a sessão e abre o login uma vez só.
class SessionExpiryHost extends ConsumerStatefulWidget {
  const SessionExpiryHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionExpiryHost> createState() => _SessionExpiryHostState();
}

class _SessionExpiryHostState extends ConsumerState<SessionExpiryHost> {
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    bindUnauthorizedSessionHandler(_onUnauthorized);
  }

  @override
  void dispose() {
    bindUnauthorizedSessionHandler(null);
    super.dispose();
  }

  Future<void> _onUnauthorized() async {
    await ref.read(sessionProvider.notifier).clear();
    if (!mounted) {
      return;
    }
    ref.read(consentProvider.notifier).clear();
    _scheduleLoginRedirect();
  }

  void _scheduleLoginRedirect() {
    if (_redirectScheduled) {
      return;
    }
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectScheduled = false;
      if (!mounted) {
        return;
      }
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        return;
      }
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AuthScreen.routeName),
          builder: (_) => const AuthScreen(),
        ),
        (route) => false,
      );
      final messenger = ScaffoldMessenger.maybeOf(navigator.context);
      if (messenger == null) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(sessionExpiredMessage)));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      final loggedIn = next.hasSession && previous?.hasSession != true;
      if (loggedIn) {
        resetUnauthorizedSessionHandling();
      }
    });
    return widget.child;
  }
}
