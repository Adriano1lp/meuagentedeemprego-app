import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Persisted auth secrets. Access token (and refresh, if the app ever
/// receives one) live only in the OS keychain/keystore.
abstract class TokenStore {
  String? get cachedAccessToken;

  Future<void> preload();

  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<void> writeAccessToken(String accessToken, {String? refreshToken});

  Future<void> clearTokens();
}

TokenStore? _activeTokenStore;

void bindActiveTokenStore(TokenStore store) {
  _activeTokenStore = store;
}

TokenStore get activeTokenStore {
  _activeTokenStore ??= SecureTokenStore();
  return _activeTokenStore!;
}

Future<Map<String, String>> resolveBearerHeaders(
  TokenStore store, {
  String? fallbackToken,
}) async {
  final stored = await store.readAccessToken();
  final token = (stored != null && stored.trim().isNotEmpty)
      ? stored
      : fallbackToken;
  if (token == null || token.trim().isEmpty) {
    return {};
  }
  return {'Authorization': 'Bearer ${token.trim()}'};
}

class SessionStorageKeys {
  static const hiveBoxName = 'app_session';
  static const hiveAuthToken = 'auth_token';
  static const installMarker = 'install_marker';
  static const installMarkerValue = '1';
  static const accessToken = 'access_token';
  static const refreshToken = 'refresh_token';
}

class SessionBootstrap {
  /// Wipes leftover Keychain values after uninstall/reinstall, then migrates
  /// any plaintext Hive token into secure storage.
  static Future<void> prepare(Box<String> sessionBox, TokenStore store) async {
    if (sessionBox.get(SessionStorageKeys.installMarker) !=
        SessionStorageKeys.installMarkerValue) {
      await store.clearTokens();
      await sessionBox.put(
        SessionStorageKeys.installMarker,
        SessionStorageKeys.installMarkerValue,
      );
    }

    await migrateLegacyHiveToken(sessionBox, store);
    await store.preload();
  }

  static Future<void> migrateLegacyHiveToken(
    Box<String> sessionBox,
    TokenStore store,
  ) async {
    final legacy = sessionBox.get(SessionStorageKeys.hiveAuthToken);
    if (legacy == null || legacy.trim().isEmpty) {
      await sessionBox.delete(SessionStorageKeys.hiveAuthToken);
      return;
    }

    final current = await store.readAccessToken();
    if (current == null || current.trim().isEmpty) {
      await store.writeAccessToken(legacy);
    }
    await sessionBox.delete(SessionStorageKeys.hiveAuthToken);
  }
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore({String? accessToken, String? refreshToken})
    : _accessToken = accessToken,
      _refreshToken = refreshToken;

  String? _accessToken;
  String? _refreshToken;

  @override
  String? get cachedAccessToken => _accessToken;

  @override
  Future<void> preload() async {}

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> writeAccessToken(String accessToken, {String? refreshToken}) async {
    _accessToken = accessToken;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  final FlutterSecureStorage _storage;
  String? _cachedAccessToken;
  String? _cachedRefreshToken;

  @override
  String? get cachedAccessToken => _cachedAccessToken;

  @override
  Future<void> preload() async {
    _cachedAccessToken = _normalize(
      await _storage.read(key: SessionStorageKeys.accessToken),
    );
    _cachedRefreshToken = _normalize(
      await _storage.read(key: SessionStorageKeys.refreshToken),
    );
  }

  @override
  Future<String?> readAccessToken() async {
    _cachedAccessToken = _normalize(
      await _storage.read(key: SessionStorageKeys.accessToken),
    );
    return _cachedAccessToken;
  }

  @override
  Future<String?> readRefreshToken() async {
    _cachedRefreshToken = _normalize(
      await _storage.read(key: SessionStorageKeys.refreshToken),
    );
    return _cachedRefreshToken;
  }

  @override
  Future<void> writeAccessToken(String accessToken, {String? refreshToken}) async {
    final normalized = accessToken.trim();
    await _storage.write(
      key: SessionStorageKeys.accessToken,
      value: normalized,
    );
    _cachedAccessToken = normalized;

    if (refreshToken != null) {
      final normalizedRefresh = refreshToken.trim();
      if (normalizedRefresh.isEmpty) {
        await _storage.delete(key: SessionStorageKeys.refreshToken);
        _cachedRefreshToken = null;
      } else {
        await _storage.write(
          key: SessionStorageKeys.refreshToken,
          value: normalizedRefresh,
        );
        _cachedRefreshToken = normalizedRefresh;
      }
    }
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: SessionStorageKeys.accessToken);
    await _storage.delete(key: SessionStorageKeys.refreshToken);
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
  }

  static String? _normalize(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
