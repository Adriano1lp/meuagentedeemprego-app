import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/models/message_model.dart';

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
      final box = Hive.box<String>('app_session');
      return SessionNotifier(box);
    });

class SessionState {
  final String? authToken;
  final String? userId;
  final String? email;
  final String? displayName;
  final bool hasCv;
  final bool termsAccepted;

  const SessionState({
    this.authToken,
    this.userId,
    this.email,
    this.displayName,
    this.hasCv = false,
    this.termsAccepted = false,
  });

  bool get hasSession => authToken != null && authToken!.trim().isNotEmpty;

  SessionState copyWith({
    String? authToken,
    String? userId,
    String? email,
    String? displayName,
    bool? hasCv,
    bool? termsAccepted,
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
      termsAccepted: termsAccepted ?? this.termsAccepted,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._box)
    : super(
        SessionState(
          authToken: _box.get(_authTokenKey),
          userId: _box.get(_userIdKey),
          email: _box.get(_emailKey),
          displayName: _box.get(_displayNameKey),
          hasCv: _box.get(_hasCvKey) == 'true',
          termsAccepted: _box.get(_termsAcceptedKey) == 'true',
        ),
      );

  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'email';
  static const String _displayNameKey = 'display_name';
  static const String _hasCvKey = 'has_cv';
  static const String _termsAcceptedKey = 'terms_accepted';

  final Box<String> _box;

  Future<void> saveSession({
    required String authToken,
    required String userId,
    required String email,
    required String displayName,
    required bool hasCv,
    required bool termsAccepted,
  }) async {
    final normalizedUserId = normalizeUserId(userId);
    if (state.userId != normalizedUserId) {
      await Hive.box<MessageModel>('chat_history').clear();
    }

    await _box.put(_authTokenKey, authToken);
    await _box.put(_userIdKey, normalizedUserId);
    await _box.put(_emailKey, email.trim().toLowerCase());
    await _box.put(_displayNameKey, displayName.trim());
    await _box.put(_hasCvKey, hasCv.toString());
    await _box.put(_termsAcceptedKey, termsAccepted.toString());

    state = SessionState(
      authToken: authToken,
      userId: normalizedUserId,
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      hasCv: hasCv,
      termsAccepted: termsAccepted,
    );
  }

  Future<void> updateHasCv(bool hasCv) async {
    await _box.put(_hasCvKey, hasCv.toString());
    state = state.copyWith(hasCv: hasCv);
  }

  Future<void> updateTermsAccepted(bool termsAccepted) async {
    await _box.put(_termsAcceptedKey, termsAccepted.toString());
    state = state.copyWith(termsAccepted: termsAccepted);
  }

  Future<void> clear() async {
    await Hive.box<MessageModel>('chat_history').clear();
    await _box.delete(_authTokenKey);
    await _box.delete(_userIdKey);
    await _box.delete(_emailKey);
    await _box.delete(_displayNameKey);
    await _box.delete(_hasCvKey);
    await _box.delete(_termsAcceptedKey);
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
