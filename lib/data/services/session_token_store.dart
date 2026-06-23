import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionTokenStore {
  Future<String?> readToken();

  Future<void> saveToken(String token);

  Future<void> deleteToken();

  Future<bool> hasToken();
}

class SecureSessionTokenStore implements SessionTokenStore {
  SecureSessionTokenStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() {
    return _storage.read(key: _tokenKey);
  }

  @override
  Future<void> saveToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<void> deleteToken() {
    return _storage.delete(key: _tokenKey);
  }

  @override
  Future<bool> hasToken() async {
    final token = await readToken();
    return token != null && token.trim().isNotEmpty;
  }
}
