import 'package:dio/dio.dart';

import '../api_config.dart';
import '../cv_file_name.dart';
import '../token_store.dart';

const String cvDownloadFailedMessage =
    'Nao foi possivel baixar o curriculo. Tente novamente.';

/// Fixed user-facing failure. Never carries status text, paths, or tokens.
class CvDownloadException implements Exception {
  const CvDownloadException();

  @override
  String toString() => cvDownloadFailedMessage;
}

/// Downloads one CV with the JWT from [TokenStore] (secure storage in the app).
///
/// Bytes stay in memory for the caller to hand to the existing PDF opener.
/// They are not written to Hive or any other app clear-text store.
class CvFileRepository {
  CvFileRepository({Dio? dio, TokenStore? tokenStore})
    : _tokenStore = tokenStore ?? activeTokenStore,
      _dio =
          dio ??
          createApiDio(
            tokenStore: tokenStore,
            responseType: ResponseType.bytes,
          ) {
    _installBearerOnlyInterceptor(_dio);
  }

  final Dio _dio;
  final TokenStore _tokenStore;

  static const String filesPathPrefix = '/users/me/files/';

  Future<List<int>> downloadBytes(String fileName) async {
    final safeName = sanitizeCvFileName(fileName);
    final token = await _tokenStore.readAccessToken();
    if (safeName == null || token == null || token.isEmpty) {
      throw const CvDownloadException();
    }

    try {
      final response = await _dio.get<List<int>>(
        '$filesPathPrefix${Uri.encodeComponent(safeName)}',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw const CvDownloadException();
      }

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const CvDownloadException();
      }
      return bytes;
    } on CvDownloadException {
      rethrow;
    } catch (_) {
      throw const CvDownloadException();
    }
  }

  static void _installBearerOnlyInterceptor(Dio dio) {
    if (dio.interceptors.any((item) => item is _CvFilesBearerOnlyInterceptor)) {
      return;
    }
    dio.interceptors.add(const _CvFilesBearerOnlyInterceptor());
  }
}

/// Identity for CV download is the Bearer JWT only.
class _CvFilesBearerOnlyInterceptor extends Interceptor {
  const _CvFilesBearerOnlyInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/users/me/files/')) {
      options.headers.remove('X-User-Id');
      options.headers.remove('x-user-id');
    }
    handler.next(options);
  }
}
