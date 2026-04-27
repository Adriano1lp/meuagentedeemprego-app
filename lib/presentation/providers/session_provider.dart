import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/models/message_model.dart';

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((
  ref,
) {
  final box = Hive.box<String>('app_session');
  return SessionNotifier(box);
});

class SessionState {
  final String? userId;

  const SessionState({this.userId});

  bool get hasUser => userId != null && userId!.trim().isNotEmpty;

  SessionState copyWith({String? userId, bool clearUser = false}) {
    return SessionState(userId: clearUser ? null : (userId ?? this.userId));
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._box)
    : super(SessionState(userId: _box.get(_userIdKey)));

  static const String _userIdKey = 'user_id';

  final Box<String> _box;

  Future<void> setUserId(String userId) async {
    final normalized = normalizeUserId(userId);
    if (state.userId != normalized) {
      await Hive.box<MessageModel>('chat_history').clear();
    }
    await _box.put(_userIdKey, normalized);
    state = SessionState(userId: normalized);
  }

  Future<void> clear() async {
    await Hive.box<MessageModel>('chat_history').clear();
    await _box.delete(_userIdKey);
    state = const SessionState();
  }

  static String normalizeUserId(String value) {
    final trimmed = value.trim();
    final normalized = trimmed
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^[_\.-]+|[_\.-]+$'), '');

    if (normalized.isEmpty) {
      throw const FormatException('Informe um nome de usuario valido.');
    }

    return normalized;
  }
}
