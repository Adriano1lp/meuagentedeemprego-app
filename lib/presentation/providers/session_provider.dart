import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/models/message_model.dart';
import '../../data/token_store.dart';

final secureTokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore();
});

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
      final box = Hive.box<String>(SessionStorageKeys.hiveBoxName);
      return SessionNotifier(box, ref.watch(secureTokenStoreProvider));
    });

class SessionState {
  final String? authToken;
  final String? userId;
  final String? email;
  final String? displayName;
  final bool hasCv;

  const SessionState({
    this.authToken,
    this.userId,
    this.email,
    this.displayName,
    this.hasCv = false,
  });

  bool get hasSession => authToken != null && authToken!.trim().isNotEmpty;

  SessionState copyWith({
    String? authToken,
    String? userId,
    String? email,
    String? displayName,
    bool? hasCv,
    bool clear = false,
  }) {
    if (clear) {
      return const SessionState();
    }

    return SessionState(
      authToken: authToken ?? this.authToken,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      hasCv: hasCv ?? this.hasCv,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._box, this._tokenStore)
    : super(
        SessionState(
          authToken: _tokenStore.cachedAccessToken,
          userId: _box.get(_userIdKey),
          email: _box.get(_emailKey),
          displayName: _box.get(_displayNameKey),
          hasCv: _box.get(_hasCvKey) == 'true',
        ),
      );

  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'email';
  static const String _displayNameKey = 'display_name';
  static const String _hasCvKey = 'has_cv';

  final Box<String> _box;
  final TokenStore _tokenStore;

  Future<String?> readAccessToken() => _tokenStore.readAccessToken();

  Future<void> saveSession({
    required String authToken,
    required String userId,
    required String email,
    required String displayName,
    required bool hasCv,
    String? refreshToken,
  }) async {
    final normalizedUserId = normalizeUserId(userId);
    if (state.userId != normalizedUserId) {
      await Hive.box<MessageModel>('chat_history').clear();
    }

    await _tokenStore.writeAccessToken(authToken, refreshToken: refreshToken);
    await _box.delete(SessionStorageKeys.hiveAuthToken);
    await _box.put(_userIdKey, normalizedUserId);
    await _box.put(_emailKey, email.trim().toLowerCase());
    await _box.put(_displayNameKey, displayName.trim());
    await _box.put(_hasCvKey, hasCv.toString());

    state = SessionState(
      authToken: authToken,
      userId: normalizedUserId,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      hasCv: hasCv,
    );
  }

  Future<void> updateHasCv(bool hasCv) async {
    await _box.put(_hasCvKey, hasCv.toString());
    state = state.copyWith(hasCv: hasCv);
  }

  Future<void> clear() async {
    await Hive.box<MessageModel>('chat_history').clear();
    await _tokenStore.clearTokens();
    await _box.delete(SessionStorageKeys.hiveAuthToken);
    await _box.delete(_userIdKey);
    await _box.delete(_emailKey);
    await _box.delete(_displayNameKey);
    await _box.delete(_hasCvKey);
    state = const SessionState();
  }

  static String normalizeUserId(String value) {
    final trimmed = value.trim();
    final normalized = trimmed
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^[_\.-]+|[_\.-]+$'), '');

    if (normalized.isEmpty) {
      throw const FormatException('Informe um identificador de usuario valido.');
    }

    return normalized;
  }
}
