import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/chat_message.dart';
import '../api_config.dart';
import '../api_errors.dart';
import '../models/gap_history_item.dart';
import '../models/message_model.dart';
import '../token_store.dart';

class ChatRepositoryImpl {
  static String get apiBaseUrl => ApiConfig.apiBaseUrl;

  /// Live `/processar` often takes ~25–30s (LLM + PDF). Scoped to this call
  /// so login/status/upload keep the shorter Dio default.
  static const Duration processarReceiveTimeout = Duration(seconds: 120);
  static const Duration processarSendTimeout = Duration(seconds: 60);
  static const Duration processarConnectTimeout = Duration(seconds: 30);
  static const String gapHistoryPath = '/users/me/gap-history';

  final Box<MessageModel> _box;
  final TokenStore _tokenStore;
  final String? _userId;
  final Dio _dio;

  ChatRepositoryImpl(
    this._box, {
    TokenStore? tokenStore,
    String? userId,
    Dio? dio,
  }) : _tokenStore = tokenStore ?? activeTokenStore,
       _userId = userId,
       _dio = dio ?? createApiDio(tokenStore: tokenStore ?? activeTokenStore);

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
        options: processarRequestOptions(headers: await _buildAuthHeaders()),
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

  /// Past analyses persisted by POST `/processar` on the API.
  Future<List<GapHistoryItem>> fetchGapHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final authToken = await _tokenStore.readAccessToken();
    if (authToken == null || authToken.trim().isEmpty) {
      throw Exception('Entre na sua conta para ver o historico.');
    }

    try {
      final response = await _dio.get<dynamic>(
        gapHistoryPath,
        queryParameters: {'limit': limit, 'offset': offset},
        options: Options(headers: await _buildAuthHeaders()),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro no servidor: ${response.statusCode}');
      }

      return GapHistoryItem.listFromResponse(response.data);
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Falha ao carregar o historico',
        apiBaseUrl: apiBaseUrl,
      );
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

  static Options processarRequestOptions({
    required Map<String, String> headers,
  }) {
    return Options(
      headers: headers,
      receiveTimeout: processarReceiveTimeout,
      sendTimeout: processarSendTimeout,
      connectTimeout: processarConnectTimeout,
    );
  }

  Future<Map<String, String>> _buildAuthHeaders() async {
    final authToken = await _tokenStore.readAccessToken();
    if (authToken != null && authToken.trim().isNotEmpty) {
      return {'Authorization': 'Bearer $authToken'};
    }

    return {'X-User-Id': _userId ?? ''};
  }
}
