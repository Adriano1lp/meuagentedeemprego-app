import 'package:dio/dio.dart';

import 'chat_repository_impl.dart';

class UserRepositoryImpl {
  UserRepositoryImpl()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ChatRepositoryImpl.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final Dio _dio;

  Options _userOptions(String userId) {
    return Options(headers: {'X-User-Id': userId});
  }

  Future<void> uploadCv({
    required String userId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '/users/me/upload-cv',
        data: formData,
        options: _userOptions(userId),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro no upload do curriculo: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Tempo de conexao esgotado');
      }

      if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Nao foi possivel alcancar a API em ${ChatRepositoryImpl.apiBaseUrl}. '
          'No celular, localhost aponta para o proprio aparelho. '
          'Use o IP do computador na rede local.',
        );
      }

      final detail = e.response?.data;
      if (detail is Map<String, dynamic> && detail['detail'] is String) {
        throw Exception(detail['detail'] as String);
      }

      if (e.response?.statusCode == 404) {
        throw Exception('Endpoint upload-cv nao encontrado');
      }

      throw Exception('Falha ao enviar curriculo');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }

  Future<void> rebuildEmbeddings({required String userId}) async {
    try {
      final response = await _dio.post(
        '/users/me/rebuild-embeddings',
        options: _userOptions(userId),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro ao processar curriculo: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Tempo de conexao esgotado');
      }

      if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Nao foi possivel alcancar a API em ${ChatRepositoryImpl.apiBaseUrl}. '
          'No celular, localhost aponta para o proprio aparelho. '
          'Use o IP do computador na rede local.',
        );
      }

      final detail = e.response?.data;
      if (detail is Map<String, dynamic> && detail['detail'] is String) {
        throw Exception(detail['detail'] as String);
      }

      if (e.response?.statusCode == 404) {
        throw Exception('Endpoint rebuild-embeddings nao encontrado');
      }

      throw Exception('Falha ao processar curriculo');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }
}
