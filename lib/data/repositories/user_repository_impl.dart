import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api_errors.dart';
import 'chat_repository_impl.dart';

class UserRepositoryImpl {
  UserRepositoryImpl()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ChatRepositoryImpl.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ) {
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestHeader: true,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          error: true,
        ),
      );
    }
  }

  final Dio _dio;

  Options _userOptions({
    String? authToken,
    String? userId,
  }) {
    if (authToken != null && authToken.trim().isNotEmpty) {
      return Options(headers: {'Authorization': 'Bearer $authToken'});
    }
    return Options(headers: {'X-User-Id': userId});
  }

  Future<void> uploadCv({
    required String authToken,
    required String fileName,
    String? filePath,
    List<int>? fileBytes,
  }) async {
    if (fileName.trim().isEmpty) {
      throw Exception('Nome do arquivo invalido');
    }

    if (fileBytes == null && (filePath == null || filePath.trim().isEmpty)) {
      throw Exception('Nao foi possivel ler o arquivo selecionado');
    }

    try {
      final multipartFile = fileBytes != null
          ? MultipartFile.fromBytes(fileBytes, filename: fileName)
          : await MultipartFile.fromFile(filePath!, filename: fileName);

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      final response = await _dio.post(
        '/users/me/upload-cv',
        data: formData,
        options: _userOptions(authToken: authToken),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro no upload do curriculo: ${response.statusCode}');
      }
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Falha ao enviar curriculo',
        apiBaseUrl: ChatRepositoryImpl.apiBaseUrl,
      );
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }

  Future<void> rebuildEmbeddings({required String authToken}) async {
    try {
      final response = await _dio.post(
        '/users/me/rebuild-embeddings',
        options: _userOptions(authToken: authToken),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro ao processar curriculo: ${response.statusCode}');
      }
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Falha ao processar curriculo',
        apiBaseUrl: ChatRepositoryImpl.apiBaseUrl,
      );
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  }
}
