import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/chat_message.dart';
import '../api_errors.dart';
import '../models/message_model.dart';

class ChatRepositoryImpl {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  final Box<MessageModel> _box;
  final String? _authToken;
  final String? _userId;
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  ChatRepositoryImpl(this._box, {String? authToken, String? userId})
    : _authToken = authToken,
      _userId = userId;

  Future<ChatMessage> sendMessage(String text) async {
    final authToken = _authToken;
    final userId = _userId;

    if ((authToken == null || authToken.trim().isEmpty) &&
        (userId == null || userId.trim().isEmpty)) {
      throw Exception('Entre na sua conta antes de enviar mensagens.');
    }

    try {
      final response = await _dio.post(
        '/processar',
        data: {'texto': text},
        options: Options(headers: _buildAuthHeaders()),
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

  Map<String, String> _buildAuthHeaders() {
    final authToken = _authToken;
    if (authToken != null && authToken.trim().isNotEmpty) {
      return {'Authorization': 'Bearer $authToken'};
    }

    return {'X-User-Id': _userId ?? ''};
  }
}
