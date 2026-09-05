import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/consent_provider.dart';
import '../providers/session_provider.dart';
import '../screens/consent_reaccept_screen.dart';

class ConsentGate extends ConsumerWidget {
  const ConsentGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionProvider, (previous, next) {
      if (previous?.hasSession == true && !next.hasSession) {
        ref.read(consentProvider.notifier).clear();
      }
    });

    final session = ref.watch(sessionProvider);
    final consent = ref.watch(consentProvider);
    final blocked = session.hasSession && consent.blocksApp;

    return PopScope(
      canPop: !blocked,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: blocked,
            child: child,
          ),
          if (blocked) const ConsentReacceptScreen(),
        ],
      ),
    );
  }
}
