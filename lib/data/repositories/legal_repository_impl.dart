import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_config.dart';
import '../api_errors.dart';
import '../legal_versions.dart';
import '../token_store.dart';
import 'chat_repository_impl.dart';

abstract class LegalRepository {
  Future<LegalDocumentData> fetchDocument(LegalDoc doc, {String? version});

  Future<void> acceptConsent({
    required String authToken,
    required LegalDoc doc,
    String? version,
  });
}

final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepositoryImpl();
});

class LegalDocumentData {
  final LegalDoc doc;
  final String version;
  final String markdown;

  const LegalDocumentData({
    required this.doc,
    required this.version,
    required this.markdown,
  });
}

class LegalRepositoryImpl implements LegalRepository {
  LegalRepositoryImpl({Dio? dio, TokenStore? tokenStore})
    : _tokenStore = tokenStore ?? activeTokenStore,
      _dio = dio ?? createApiDio(tokenStore: tokenStore);

  final Dio _dio;
  final TokenStore _tokenStore;

  @override
  Future<LegalDocumentData> fetchDocument(
    LegalDoc doc, {
    String? version,
  }) async {
    final resolvedVersion = (version ?? doc.currentVersion).trim();
    try {
      final response = await _dio.get<dynamic>(
        '/legal/${doc.apiValue}',
        queryParameters: {'version': resolvedVersion},
        options: Options(
          responseType: ResponseType.plain,
          headers: const {'Accept': 'text/markdown, text/plain, */*'},
        ),
      );

      final markdown = _asMarkdown(response.data);
      if (markdown.trim().isEmpty) {
        throw Exception('Documento legal vazio');
      }

      return LegalDocumentData(
        doc: doc,
        version: resolvedVersion,
        markdown: markdown,
      );
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Nao foi possivel carregar ${doc.title}',
        apiBaseUrl: ChatRepositoryImpl.apiBaseUrl,
      );
    }
  }

  @override
  Future<void> acceptConsent({
    required String authToken,
    required LegalDoc doc,
    String? version,
  }) async {
    final resolvedVersion = (version ?? doc.currentVersion).trim();
    try {
      final response = await _dio.post<dynamic>(
        '/consent',
        data: buildConsentRequest(doc, version: resolvedVersion),
        options: Options(
          headers: await _bearerHeaders(authToken),
        ),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro ao registrar aceite: ${response.statusCode}');
      }
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Falha ao registrar o aceite de ${doc.title}',
        apiBaseUrl: ChatRepositoryImpl.apiBaseUrl,
      );
    }
  }

  String _asMarkdown(dynamic data) {
    if (data is String) {
      return data;
    }
    if (data is List<int>) {
      return String.fromCharCodes(data);
    }
    return data?.toString() ?? '';
  }

  Future<Map<String, String>> _bearerHeaders(String fallbackToken) {
    return resolveBearerHeaders(_tokenStore, fallbackToken: fallbackToken);
  }
}
