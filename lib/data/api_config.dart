import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'token_store.dart';

class ApiConfig {
  static const String rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static String get apiBaseUrl => resolveApiBaseUrl(rawApiBaseUrl);

  /// Release/profile builds must talk to HTTPS only. Debug keeps `http://`
  /// so local API development still works.
  static String resolveApiBaseUrl(String url, {bool? isDebug}) {
    final debug = isDebug ?? kDebugMode;
    if (!debug && !_isHttps(url)) {
      throw StateError(
        'apiBaseUrl deve usar HTTPS em builds que nao sao debug. Valor: $url',
      );
    }
    return url;
  }

  static bool _isHttps(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}

Dio createApiDio({
  Duration connectTimeout = const Duration(seconds: 30),
  Duration receiveTimeout = const Duration(seconds: 30),
  TokenStore? tokenStore,
  ResponseType? responseType,
  Map<String, dynamic>? headers,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.apiBaseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      responseType: responseType ?? ResponseType.json,
      headers: headers,
    ),
  );
  dio.interceptors.add(SecureAuthInterceptor(tokenStore ?? activeTokenStore));
  return dio;
}

class SecureAuthInterceptor extends Interceptor {
  SecureAuthInterceptor(this._store);

  final TokenStore _store;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    _attach(options)
        .then((_) => handler.next(options))
        .catchError((Object error, StackTrace stackTrace) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: error,
              stackTrace: stackTrace,
            ),
          );
        });
  }

  Future<void> _attach(RequestOptions options) async {
    final stored = await _store.readAccessToken();
    if (stored != null && stored.trim().isNotEmpty) {
      options.headers['Authorization'] = 'Bearer ${stored.trim()}';
    }
  }
}
