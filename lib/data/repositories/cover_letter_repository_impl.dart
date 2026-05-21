import 'package:dio/dio.dart';

import '../../domain/entities/chat_message.dart';
import 'chat_repository_impl.dart';

class CoverLetterRepositoryImpl {
  CoverLetterRepositoryImpl()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ChatRepositoryImpl.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final Dio _dio;

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
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
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
      throw Exception(_extractErrorMessage(e));
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

  String _extractErrorMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout) {
      return 'Tempo de conexao esgotado';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Nao foi possivel alcancar a API em ${ChatRepositoryImpl.apiBaseUrl}.';
    }

    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }

    if (error.response?.statusCode == 404) {
      return 'Endpoint de carta de apresentacao nao encontrado';
    }

    return 'Falha ao gerar carta de apresentacao';
  }
}
