import 'package:dio/dio.dart';

import 'consent_outdated.dart';

const String historyLoginRequiredMessage =
    'Entre na sua conta para ver o historico.';
const String historySessionExpiredMessage =
    'Sessao expirada. Entre novamente para ver o historico.';
const String historyLoadFailedMessage =
    'Nao foi possivel carregar o historico. Tente novamente.';

/// User-facing history errors only. Never includes URLs, API paths, tokens,
/// or FastAPI/traceback `detail`.
String safeHistoryErrorMessage(Object error) {
  if (error is ConsentOutdatedException) {
    return error.message;
  }

  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return historySessionExpiredMessage;
    }
  }

  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  if (raw == historyLoginRequiredMessage) {
    return historyLoginRequiredMessage;
  }
  if (raw == historySessionExpiredMessage) {
    return historySessionExpiredMessage;
  }

  return historyLoadFailedMessage;
}

bool historyErrorLeaksInternals(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('http://') || lower.contains('https://')) {
    return true;
  }
  if (lower.contains('/users/me') || lower.contains('gap-history')) {
    return true;
  }
  if (lower.contains('authorization') || lower.contains('bearer ')) {
    return true;
  }
  if (RegExp(r'\.py\b').hasMatch(lower) || lower.contains('traceback')) {
    return true;
  }
  if (lower.contains('jwt-') || lower.contains('access_token')) {
    return true;
  }
  return false;
}
