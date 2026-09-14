import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/analyze_gate.dart';
import '../../data/consent_outdated.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import '../validators/job_description_validator.dart';
import 'consent_provider.dart';
import 'session_provider.dart';

typedef UserStatusFetcher = Future<UserStatusData> Function();

final userStatusFetcherProvider = Provider<UserStatusFetcher>((ref) {
  return () async {
    final token = await ref.read(sessionProvider.notifier).readAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Entre na sua conta antes de analisar vagas.');
    }
    return AuthRepositoryImpl(
      tokenStore: ref.read(secureTokenStoreProvider),
    ).getUserStatus(token);
  };
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final box = Hive.box<MessageModel>('chat_history');
  // Watch userId only. hasCv updates from this notifier must not recreate it.
  final userId = ref.watch(sessionProvider.select((session) => session.userId));
  return ChatNotifier(
    ChatRepositoryImpl(
      box,
      tokenStore: ref.watch(secureTokenStoreProvider),
      userId: userId,
    ),
    fetchUserStatus: () => ref.read(userStatusFetcherProvider)(),
    onStatusResolved: (status) {
      ref.read(sessionProvider.notifier).updateHasCv(
        status.hasCv && status.hasEmbeddings,
      );
    },
    onConsentOutdated: (error) {
      ref.read(consentProvider.notifier).applyException(error);
    },
  );
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final bool isCheckingStatus;
  final bool canAnalyze;
  final bool statusResolved;
  final String? analyzeBlockReason;

  const ChatState({
    required this.messages,
    this.isLoading = false,
    this.errorMessage,
    this.isCheckingStatus = false,
    this.canAnalyze = false,
    this.statusResolved = false,
    this.analyzeBlockReason,
  });

  bool get embeddingsMissing => statusResolved && !canAnalyze;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? isCheckingStatus,
    bool? canAnalyze,
    bool? statusResolved,
    String? analyzeBlockReason,
    bool clearAnalyzeBlock = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isCheckingStatus: isCheckingStatus ?? this.isCheckingStatus,
      canAnalyze: canAnalyze ?? this.canAnalyze,
      statusResolved: statusResolved ?? this.statusResolved,
      analyzeBlockReason: clearAnalyzeBlock
          ? null
          : (analyzeBlockReason ?? this.analyzeBlockReason),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepositoryImpl _repository;
  final UserStatusFetcher? fetchUserStatus;
  final void Function(UserStatusData status)? onStatusResolved;
  final void Function(ConsentOutdatedException error)? onConsentOutdated;

  ChatNotifier(
    this._repository, {
    this.fetchUserStatus,
    this.onStatusResolved,
    this.onConsentOutdated,
  }) : super(ChatState(messages: _repository.getHistory()));

  Future<void> refreshAnalysisReadiness() async {
    final fetcher = fetchUserStatus;
    if (fetcher == null) {
      state = state.copyWith(
        canAnalyze: true,
        statusResolved: true,
        isCheckingStatus: false,
        clearAnalyzeBlock: true,
      );
      return;
    }

    state = state.copyWith(isCheckingStatus: true, clearError: true);

    try {
      final status = await fetcher();
      onStatusResolved?.call(status);
      final canAnalyze = AnalyzeGate.canAnalyze(status);
      state = state.copyWith(
        isCheckingStatus: false,
        canAnalyze: canAnalyze,
        statusResolved: true,
        analyzeBlockReason: AnalyzeGate.blockReason(status),
        clearAnalyzeBlock: canAnalyze,
      );
    } catch (e) {
      final consentError = ConsentOutdatedException.fromError(e);
      if (consentError != null) {
        onConsentOutdated?.call(consentError);
      }
      state = state.copyWith(
        isCheckingStatus: false,
        canAnalyze: false,
        statusResolved: false,
        analyzeBlockReason: AnalyzeGate.waitingStatusMessage,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> sendMessage(String text) async {
    if (state.isLoading || state.isCheckingStatus) return false;

    final trimmedText = text.trim();
    final validation = JobDescriptionValidator.validate(trimmedText);
    if (!validation.isValid) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: validation.message,
      );
      return false;
    }

    if (fetchUserStatus != null) {
      await refreshAnalysisReadiness();
      if (!state.canAnalyze) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              state.analyzeBlockReason ?? AnalyzeGate.missingEmbeddingsMessage,
        );
        return false;
      }
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
