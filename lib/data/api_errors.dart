import 'package:dio/dio.dart';

import 'consent_outdated.dart';

String extractApiErrorMessage(
  DioException error, {
  required String fallback,
  String? apiBaseUrl,
}) {
  if (error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return 'A analise demorou demais. Tente novamente.';
  }

  if (error.type == DioExceptionType.connectionTimeout) {
    return 'Tempo de conexao esgotado';
  }

  if (error.type == DioExceptionType.connectionError) {
    if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
      return 'Nao foi possivel alcancar a API em $apiBaseUrl.';
    }
    return 'Nao foi possivel alcancar a API.';
  }

  final status = error.response?.statusCode;
  final detail = extractFastApiDetail(error.response?.data);
  if (detail != null) {
    return status != null ? 'HTTP $status: $detail' : detail;
  }

  if (status == 404) {
    return 'HTTP 404: Endpoint nao encontrado';
  }
  if (status != null) {
    return 'HTTP $status: $fallback';
  }

  return fallback;
}

/// FastAPI-style `detail`: string, `{message}`, or validation list.
String? extractFastApiDetail(dynamic data) {
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    if (detail is Map) {
      final message = detail['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map) {
        final message = first['msg'] ?? first['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      if (first is String && first.trim().isNotEmpty) {
        return first.trim();
      }
    }
  }

  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }

  return null;
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
