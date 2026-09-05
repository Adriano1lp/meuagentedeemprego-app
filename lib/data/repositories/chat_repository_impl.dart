import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/chat_message.dart';
import '../api_config.dart';
import '../api_errors.dart';
import '../models/message_model.dart';
import '../token_store.dart';

class ChatRepositoryImpl {
  static String get apiBaseUrl => ApiConfig.apiBaseUrl;

  final Box<MessageModel> _box;
  final TokenStore _tokenStore;
  final String? _userId;
  final Dio _dio;

  ChatRepositoryImpl(
    this._box, {
    TokenStore? tokenStore,
    String? userId,
  }) : _tokenStore = tokenStore ?? activeTokenStore,
       _userId = userId,
       _dio = createApiDio(tokenStore: tokenStore ?? activeTokenStore);

  Future<ChatMessage> sendMessage(String text) async {
    final authToken = await _tokenStore.readAccessToken();
    final userId = _userId;

    if ((authToken == null || authToken.trim().isEmpty) &&
        (userId == null || userId.trim().isEmpty)) {
      throw Exception('Entre na sua conta antes de enviar mensagens.');
    }

    try {
      final response = await _dio.post(
        '/processar',
        data: {'texto': text},
        options: Options(headers: await _buildAuthHeaders()),
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
            : 'Sem resposta de texto',
        pdfUrl: _normalizePdfUrl(data['pdf_url']),
        isUser: false,
        timestamp: DateTime.now(),
      );
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Falha ao conectar com a API',
        apiBaseUrl: apiBaseUrl,
      );
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }

  Future<void> saveToDisk(ChatMessage message) async {
    await _box.add(MessageModel.fromEntity(message));
  }

  List<ChatMessage> getHistory() {
    return _box.values.map((m) => m.toEntity()).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
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

  Future<Map<String, String>> _buildAuthHeaders() async {
    final authToken = await _tokenStore.readAccessToken();
    if (authToken != null && authToken.trim().isNotEmpty) {
      return {'Authorization': 'Bearer $authToken'};
    }

    return {'X-User-Id': _userId ?? ''};
  }
}
