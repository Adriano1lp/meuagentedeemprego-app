import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/consent_outdated.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import '../validators/job_description_validator.dart';
import 'consent_provider.dart';
import 'session_provider.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final box = Hive.box<MessageModel>('chat_history');
  final session = ref.watch(sessionProvider);
  return ChatNotifier(
    ChatRepositoryImpl(
      box,
      tokenStore: ref.watch(secureTokenStoreProvider),
      userId: session.userId,
    ),
    onConsentOutdated: (error) {
      ref.read(consentProvider.notifier).applyException(error);
    },
  );
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  const ChatState({
    required this.messages,
    this.isLoading = false,
    this.errorMessage,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepositoryImpl _repository;
  final void Function(ConsentOutdatedException error)? onConsentOutdated;

  ChatNotifier(
    this._repository, {
    this.onConsentOutdated,
  }) : super(ChatState(messages: _repository.getHistory()));

  Future<bool> sendMessage(String text) async {
    if (state.isLoading) return false;

    final trimmedText = text.trim();
    final validation = JobDescriptionValidator.validate(trimmedText);
    if (!validation.isValid) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: validation.message,
      );
      return false;
    }

    final userMessage = ChatMessage(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      text: trimmedText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    await _repository.saveToDisk(userMessage);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      clearError: true,
    );

    try {
      final response = await _repository.sendMessage(trimmedText);
      await _repository.saveToDisk(response);

      state = state.copyWith(
        messages: [...state.messages, response],
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      final consentError = ConsentOutdatedException.fromError(e);
      if (consentError != null) {
        onConsentOutdated?.call(consentError);
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return true;
    }

    return true;
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
