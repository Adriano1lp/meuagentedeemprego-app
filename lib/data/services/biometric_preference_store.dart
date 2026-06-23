import 'package:hive/hive.dart';

enum BiometricPreferenceStatus {
  unknown,
  enabled,
  declined,
}

class BiometricPreferenceStore {
  BiometricPreferenceStore(this._box);

  static const String _prefix = 'biometric_preference';

  final Box<String> _box;

  BiometricPreferenceStatus statusForUser(String userId) {
    final value = _box.get(_keyFor(userId));
    return switch (value) {
      'enabled' => BiometricPreferenceStatus.enabled,
      'declined' => BiometricPreferenceStatus.declined,
      _ => BiometricPreferenceStatus.unknown,
    };
  }

  Future<void> enableForUser(String userId) {
    return _box.put(_keyFor(userId), 'enabled');
  }

  Future<void> declineForUser(String userId) {
    return _box.put(_keyFor(userId), 'declined');
  }

  Future<void> disableForUser(String userId) {
    return _box.delete(_keyFor(userId));
  }

  String _keyFor(String userId) {
    return '${_prefix}_${userId.trim().toLowerCase()}';
  }
}
