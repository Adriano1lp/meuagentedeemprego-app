import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/chat_message.dart';
import '../models/message_model.dart';

class ChatRepositoryImpl {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
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
      String errorMessage = 'Falha ao conectar com a API';

      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Tempo de conexao esgotado';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Nao foi possivel alcancar a API em $apiBaseUrl. '
            'No celular, localhost aponta para o proprio aparelho. '
            'Use o IP do computador na rede local.';
      } else if (_extractApiDetail(e) case final detail?) {
        errorMessage = detail;
      } else if (e.response?.statusCode == 404) {
        errorMessage = 'Endpoint nao encontrado';
      }

      throw Exception(errorMessage);
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

  String? _extractApiDetail(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      final detail = (data['detail'] as String).trim();
      if (detail.isNotEmpty) {
        return detail;
      }
    }

    return null;
  }

  Map<String, String> _buildAuthHeaders() {
    final authToken = _authToken;
    if (authToken != null && authToken.trim().isNotEmpty) {
      return {'Authorization': 'Bearer $authToken'};
    }

    return {'X-User-Id': _userId ?? ''};
  }
}
