import 'package:dio/dio.dart';

import '../../domain/entities/chat_message.dart';
import '../api_config.dart';
import '../api_errors.dart';
import '../token_store.dart';
import 'chat_repository_impl.dart';

class CoverLetterRepositoryImpl {
  CoverLetterRepositoryImpl({Dio? dio, TokenStore? tokenStore})
    : _tokenStore = tokenStore ?? activeTokenStore,
      _dio = dio ?? createApiDio(tokenStore: tokenStore);

  final Dio _dio;
  final TokenStore _tokenStore;

  Future<ChatMessage> generateCoverLetter({
    required String companyName,
    required String authToken,
  }) async {
    final empresa = companyName.trim();
    if (empresa.isEmpty) {
      throw Exception('Informe o nome da empresa.');
    }

    try {
      final response = await _dio.post(
        '/users/me/cover-letter',
        data: {'empresa': empresa},
        options: Options(headers: await _bearerHeaders(authToken)),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro no servidor: ${response.statusCode}');
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Resposta da API em formato invalido');
      }

      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: (data['texto_resposta'] as String?)?.trim().isNotEmpty == true
            ? data['texto_resposta'] as String
            : 'Carta gerada sem texto de resposta.',
        pdfUrl: _normalizePdfUrl(data['pdf_url']),
        isUser: false,
        timestamp: DateTime.now(),
      );
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Falha ao gerar carta de apresentacao',
        apiBaseUrl: ChatRepositoryImpl.apiBaseUrl,
      );
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }

  String? _normalizePdfUrl(dynamic value) {
    if (value is! String) return null;

    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || (!uri.hasScheme && !uri.isAbsolute)) {
      return null;
    }

    return trimmed;
  }

  Future<Map<String, String>> _bearerHeaders(String fallbackToken) {
    return resolveBearerHeaders(_tokenStore, fallbackToken: fallbackToken);
  }
}
