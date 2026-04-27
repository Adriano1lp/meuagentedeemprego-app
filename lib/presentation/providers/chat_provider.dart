import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import 'session_provider.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final box = Hive.box<MessageModel>('chat_history');
  final session = ref.watch(sessionProvider);
  return ChatNotifier(
    ChatRepositoryImpl(
      box,
      authToken: session.authToken,
      userId: session.userId,
    ),
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

  ChatNotifier(this._repository)
    : super(ChatState(messages: _repository.getHistory()));

  Future<void> sendMessage(String text) async {
    if (state.isLoading) return;

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

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
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
