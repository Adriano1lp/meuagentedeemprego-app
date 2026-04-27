import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/chat_repository_impl.dart';
import '../providers/session_provider.dart';
import 'pdf_file_handler.dart';

class AuthenticatedPdfOpener {
  static Future<void> open(BuildContext context, Uri uri) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final session = container.read(sessionProvider);
    final userId = session.userId;
    final authToken = session.authToken;

    if (userId == null || userId.trim().isEmpty) {
      _showMessage(messenger, 'Usuario nao encontrado para abrir o PDF.');
      return;
    }

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ChatRepositoryImpl.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: authToken != null && authToken.trim().isNotEmpty
              ? {'Authorization': 'Bearer $authToken'}
              : {'X-User-Id': userId},
          responseType: ResponseType.bytes,
        ),
      );

      final response = await dio.getUri<List<int>>(uri);
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Resposta vazia ao baixar o PDF.');
      }

      final fileName = _buildDownloadFileName(userId, uri);
      final fileHandler = createPdfFileHandler();
      await fileHandler.openPdf(bytes: bytes, fileName: fileName);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['detail'] is String) {
        _showMessage(messenger, data['detail'] as String);
        return;
      }

      _showMessage(messenger, 'Nao foi possivel baixar o PDF autenticado.');
    } catch (_) {
      _showMessage(messenger, 'Nao foi possivel abrir o PDF.');
    }
  }

  static void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _buildDownloadFileName(String userId, Uri uri) {
    final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final extension = lastSegment.toLowerCase().endsWith('.pdf') ? '.pdf' : '.pdf';
    final safeUserId = userId
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return 'curriculo_$safeUserId$extension';
  }
}
