import 'package:dio/dio.dart';

import 'consent_outdated.dart';

String extractApiErrorMessage(
  DioException error, {
  required String fallback,
  String? apiBaseUrl,
}) {
  if (error.type == DioExceptionType.connectionTimeout) {
    return 'Tempo de conexao esgotado';
  }

  if (error.type == DioExceptionType.connectionError) {
    if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
      return 'Nao foi possivel alcancar a API em $apiBaseUrl.';
    }
    return 'Nao foi possivel alcancar a API.';
  }

  final data = error.response?.data;
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    if (detail is Map && detail['message'] is String) {
      final message = (detail['message'] as String).trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
  }

  if (error.response?.statusCode == 404) {
    return 'Endpoint nao encontrado';
  }

  return fallback;
}

Never rethrowApiError(
  DioException error, {
  required String fallback,
  String? apiBaseUrl,
}) {
  final consent = ConsentOutdatedException.tryParse(error);
  if (consent != null) {
    throw consent;
  }
  throw Exception(
    extractApiErrorMessage(
      error,
      fallback: fallback,
      apiBaseUrl: apiBaseUrl,
    ),
  );
}
