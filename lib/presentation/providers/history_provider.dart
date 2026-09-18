import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/consent_outdated.dart';
import '../../data/history_errors.dart';
import '../../data/models/gap_history_item.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import 'consent_provider.dart';
import 'session_provider.dart';

typedef GapHistoryFetcher = Future<List<GapHistoryItem>> Function();

final gapHistoryFetcherProvider = Provider<GapHistoryFetcher>((ref) {
  return () {
    return ChatRepositoryImpl(
      Hive.box<MessageModel>('chat_history'),
      tokenStore: ref.read(secureTokenStoreProvider),
    ).fetchGapHistory();
  };
});

final historyProvider =
    StateNotifierProvider.autoDispose<HistoryNotifier, HistoryState>((ref) {
      return HistoryNotifier(
        fetchRemote: () => ref.read(gapHistoryFetcherProvider)(),
        onConsentOutdated: (error) {
          ref.read(consentProvider.notifier).applyException(error);
        },
      );
    });

class HistoryState {
  final List<ChatMessage> items;
  final bool isLoading;
  final String? errorMessage;
  final bool fromRemote;

  const HistoryState({
    this.items = const [],
    this.isLoading = true,
    this.errorMessage,
    this.fromRemote = false,
  });

  HistoryState copyWith({
    List<ChatMessage>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? fromRemote,
  }) {
    return HistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fromRemote: fromRemote ?? this.fromRemote,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier({
    required GapHistoryFetcher fetchRemote,
    void Function(ConsentOutdatedException error)? onConsentOutdated,
  }) : _fetchRemote = fetchRemote,
       _onConsentOutdated = onConsentOutdated,
       super(const HistoryState());

  final GapHistoryFetcher _fetchRemote;
  final void Function(ConsentOutdatedException error)? _onConsentOutdated;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final remote = await _fetchRemote();
      state = HistoryState(
        items: remote.map((item) => item.toChatMessage()).toList(),
        isLoading: false,
        fromRemote: true,
      );
    } catch (error) {
      final consentError = ConsentOutdatedException.fromError(error);
      if (consentError != null) {
        _onConsentOutdated?.call(consentError);
      }
      state = HistoryState(
        items: const [],
        isLoading: false,
        errorMessage: safeHistoryErrorMessage(error),
      );
    }
  }
}
