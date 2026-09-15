import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Persisted auth secrets. Access token (and refresh, if the app ever
/// receives one) live only in the OS keychain/keystore.
abstract class TokenStore {
  String? get cachedAccessToken;

  Future<void> preload();

  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  /// Existence check for biometric unlock. Does **not** expose the JWT to
  /// callers or Dio while reads are suppressed.
  Future<bool> hasAccessToken();

  Future<void> writeAccessToken(String accessToken, {String? refreshToken});

  Future<void> clearTokens();

  /// Hide JWT from API/session reads while the UI is biometric-locked.
  /// The ciphertext stays in the OS vault.
  void suppressReads();

  void allowReads();
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
  bool _readsSuppressed = false;

  @override
  String? get cachedAccessToken => _readsSuppressed ? null : _accessToken;

  @override
  Future<void> preload() async {}

  @override
  Future<String?> readAccessToken() async =>
      _readsSuppressed ? null : _accessToken;

  @override
  Future<String?> readRefreshToken() async =>
      _readsSuppressed ? null : _refreshToken;

  @override
  Future<bool> hasAccessToken() async {
    return _accessToken != null && _accessToken!.trim().isNotEmpty;
  }

  @override
  Future<void> writeAccessToken(String accessToken, {String? refreshToken}) async {
    _readsSuppressed = false;
    _accessToken = accessToken;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
  }

  @override
  Future<void> clearTokens() async {
    _readsSuppressed = false;
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  void suppressReads() {
    _readsSuppressed = true;
  }

  @override
  void allowReads() {
    _readsSuppressed = false;
  }
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              // Keystore-backed ciphertext. Not SharedPreferences plaintext.
              encryptedSharedPreferences: true,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  final FlutterSecureStorage _storage;
  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  bool _readsSuppressed = false;

  @override
  String? get cachedAccessToken =>
      _readsSuppressed ? null : _cachedAccessToken;

  @override
  Future<void> preload() async {
    if (_readsSuppressed) {
      return;
    }
    _cachedAccessToken = _normalize(
      await _storage.read(key: SessionStorageKeys.accessToken),
    );
    _cachedRefreshToken = _normalize(
      await _storage.read(key: SessionStorageKeys.refreshToken),
    );
  }

  @override
  Future<String?> readAccessToken() async {
    if (_readsSuppressed) {
      return null;
    }
    _cachedAccessToken = _normalize(
      await _storage.read(key: SessionStorageKeys.accessToken),
    );
    return _cachedAccessToken;
  }

  @override
  Future<String?> readRefreshToken() async {
    if (_readsSuppressed) {
      return null;
    }
    _cachedRefreshToken = _normalize(
      await _storage.read(key: SessionStorageKeys.refreshToken),
    );
    return _cachedRefreshToken;
  }

  @override
  Future<bool> hasAccessToken() async {
    if (!_readsSuppressed &&
        _cachedAccessToken != null &&
        _cachedAccessToken!.trim().isNotEmpty) {
      return true;
    }
    final stored = _normalize(
      await _storage.read(key: SessionStorageKeys.accessToken),
    );
    return stored != null;
  }

  @override
  Future<void> writeAccessToken(String accessToken, {String? refreshToken}) async {
    _readsSuppressed = false;
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
    _readsSuppressed = false;
    await _storage.delete(key: SessionStorageKeys.accessToken);
    await _storage.delete(key: SessionStorageKeys.refreshToken);
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
  }

  @override
  void suppressReads() {
    _readsSuppressed = true;
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
  }

  @override
  void allowReads() {
    _readsSuppressed = false;
  }

  static String? _normalize(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
