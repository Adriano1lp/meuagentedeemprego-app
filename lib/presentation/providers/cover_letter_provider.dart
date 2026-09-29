import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/cover_letter_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import 'session_provider.dart';

typedef GenerateCoverLetter = Future<ChatMessage> Function({
  required String companyName,
  required String authToken,
});

final generateCoverLetterProvider = Provider<GenerateCoverLetter>((ref) {
  final repository = CoverLetterRepositoryImpl(
    tokenStore: ref.watch(secureTokenStoreProvider),
  );
  return ({required String companyName, required String authToken}) {
    return repository.generateCoverLetter(
      companyName: companyName,
      authToken: authToken,
    );
  };
});
