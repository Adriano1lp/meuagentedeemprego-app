import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_navigator.dart';
import '../providers/consent_provider.dart';
import '../providers/session_provider.dart';
import '../screens/consent_reaccept_screen.dart';

class ConsentGate extends ConsumerStatefulWidget {
  const ConsentGate({super.key, required this.child});

  final Widget child;

  static const String routeName = 'consent-lock';

  @override
  ConsumerState<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends ConsumerState<ConsentGate> {
  bool _lockOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (previous?.hasSession == true && !next.hasSession) {
        ref.read(consentProvider.notifier).clear();
        if (_lockOpen) {
          _lockOpen = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _popLockRoute();
          });
        }
      }
    });

    ref.listen(consentProvider, (previous, next) {
      _syncLockRoute(next);
    });

    return widget.child;
  }

  void _syncLockRoute(ConsentState consent) {
    final shouldLock = ref.read(sessionProvider).hasSession && consent.blocksApp;
    if (shouldLock && !_lockOpen) {
      _lockOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pushLockRoute();
      });
      return;
    }

    if (!shouldLock && _lockOpen) {
      _lockOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _popLockRoute();
      });
    }
  }

  void _pushLockRoute() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) {
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        settings: const RouteSettings(name: ConsentGate.routeName),
        builder: (_) => const ConsentReacceptScreen(),
      ),
    );
  }

  void _popLockRoute() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) {
      return;
    }

    navigator.popUntil((route) {
      return route.settings.name != ConsentGate.routeName;
    });
  }
}
