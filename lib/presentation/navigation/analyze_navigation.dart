import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../screens/chat_screen.dart';
import '../screens/user_registration_screen.dart';

/// Opens Analisar vaga only when GET /users/me/status reports embeddings.
/// Otherwise forces the existing CV upload + rebuild-embeddings flow.
Future<void> openAnaliseVaga(BuildContext context, WidgetRef ref) async {
  await ref.read(chatProvider.notifier).refreshAnalysisReadiness();
  if (!context.mounted) return;

  final chat = ref.read(chatProvider);
  if (chat.embeddingsMissing) {
    final reason = chat.analyzeBlockReason;
    if (reason != null && reason.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(reason)));
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UserRegistrationScreen(),
      ),
    );
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ChatScreen(),
    ),
  );
}
