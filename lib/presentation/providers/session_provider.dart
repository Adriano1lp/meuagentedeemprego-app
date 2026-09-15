import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/models/message_model.dart';
import '../../data/services/biometric_preference_store.dart';
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
  final bool hasSession;
  final bool isLocked;
  final String? userId;
  final String? email;
  final String? displayName;
  final bool hasCv;

  const SessionState({
    this.hasSession = false,
    this.isLocked = false,
    this.userId,
    this.email,
    this.displayName,
    this.hasCv = false,
  });

  SessionState copyWith({
    bool? hasSession,
    bool? isLocked,
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
      hasSession: hasSession ?? this.hasSession,
      isLocked: isLocked ?? this.isLocked,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      hasCv: hasCv ?? this.hasCv,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._box, this._tokenStore)
    : super(_initialState(_box, _tokenStore));

  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'email';
  static const String _displayNameKey = 'display_name';
  static const String _hasCvKey = 'has_cv';
  static const String sessionLockedKey = 'session_locked';

  final Box<String> _box;
  final TokenStore _tokenStore;

  Future<String?> readAccessToken() => _tokenStore.readAccessToken();

  /// After a successful OS biometric prompt: allow reading the JWT that
  /// already lives in the vault. Does not mint a new token.
  Future<String?> revealVaultTokenAfterBiometric() async {
    _tokenStore.allowReads();
    return _tokenStore.readAccessToken();
  }

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
    await _box.put(sessionLockedKey, 'false');

    state = SessionState(
      hasSession: true,
      isLocked: false,
      userId: normalizedUserId,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      hasCv: hasCv,
    );
  }

  Future<void> updateHasCv(bool hasCv) async {
    if (state.hasCv == hasCv) {
      return;
    }
    await _box.put(_hasCvKey, hasCv.toString());
    state = state.copyWith(hasCv: hasCv);
  }

  Future<void> lock() async {
    await Hive.box<MessageModel>('chat_history').clear();
    await _box.put(sessionLockedKey, 'true');
    _tokenStore.suppressReads();
    state = state.copyWith(hasSession: false, isLocked: true);
  }

  Future<void> clear() async {
    await Hive.box<MessageModel>('chat_history').clear();
    await _tokenStore.clearTokens();
    await _box.delete(SessionStorageKeys.hiveAuthToken);
    await _box.delete(_userIdKey);
    await _box.delete(_emailKey);
    await _box.delete(_displayNameKey);
    await _box.delete(_hasCvKey);
    await _box.delete(sessionLockedKey);
    state = const SessionState();
  }

  static SessionState _initialState(Box<String> box, TokenStore tokenStore) {
    final userId = box.get(_userIdKey);
    final locked = _shouldLockOnStart(box, userId);
    if (locked) {
      tokenStore.suppressReads();
    }
    return SessionState(
      hasSession: !locked && _hasStoredToken(tokenStore.cachedAccessToken),
      isLocked: locked,
      userId: userId,
      email: box.get(_emailKey),
      displayName: box.get(_displayNameKey),
      hasCv: box.get(_hasCvKey) == 'true',
    );
  }

  static bool _shouldLockOnStart(Box<String> box, String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return false;
    }
    if (box.get(sessionLockedKey) == 'true') {
      return true;
    }
    return BiometricPreferenceStore(box).statusForUser(userId) ==
        BiometricPreferenceStatus.enabled;
  }

  static bool _hasStoredToken(String? token) {
    return token != null && token.trim().isNotEmpty;
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
