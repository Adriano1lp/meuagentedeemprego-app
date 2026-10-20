import 'package:dio/dio.dart';

/// Frase única quando o Bearer de uma rota autenticada deixa de valer.
const String sessionExpiredMessage = 'Sua sessão expirou, entre de novo';

/// 401 de login ou cadastro é credencial errada, não sessão vencida.
bool isCredentialAuthPath(String rawPath) {
  final path = _normalizedPath(rawPath);
  return path == '/auth/login' || path == '/auth/register';
}

/// True só para 401 de chamada que levou Bearer e não é login/cadastro.
bool shouldExpireSessionOnUnauthorized(DioException error) {
  if (error.response?.statusCode != 401) {
    return false;
  }
  final options = error.requestOptions;
  if (isCredentialAuthPath(options.path) ||
      isCredentialAuthPath(options.uri.path)) {
    return false;
  }
  return _requestCarriesAuthorization(options);
}

class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => sessionExpiredMessage;
}

typedef UnauthorizedSessionHandler = Future<void> Function();

UnauthorizedSessionHandler? _handler;
bool _handlingUnauthorized = false;

bool get hasUnauthorizedSessionHandler => _handler != null;

/// Liga o que a UI faz quando a API recusa o Bearer. Null desliga.
void bindUnauthorizedSessionHandler(UnauthorizedSessionHandler? handler) {
  _handler = handler;
}

/// Libera um novo encerramento depois que o usuário entra de novo.
void resetUnauthorizedSessionHandling() {
  _handlingUnauthorized = false;
}

/// Marca o primeiro 401 concorrente. Os seguintes devolvem false.
bool beginUnauthorizedSessionHandling() {
  if (_handlingUnauthorized) {
    return false;
  }
  _handlingUnauthorized = true;
  return true;
}

Future<void> notifyUnauthorizedSession() {
  final handler = _handler;
  if (handler == null) {
    return Future<void>.value();
  }
  return Future<void>.sync(handler);
}

bool _requestCarriesAuthorization(RequestOptions options) {
  for (final entry in options.headers.entries) {
    if (entry.key.toString().toLowerCase() != 'authorization') {
      continue;
    }
    final value = entry.value;
    if (value == null) {
      return false;
    }
    final text = value is List ? value.join(' ') : value.toString();
    return text.trim().isNotEmpty;
  }
  return false;
}

String _normalizedPath(String rawPath) {
  final parsed = Uri.tryParse(rawPath);
  final path = (parsed != null && parsed.hasScheme) ? parsed.path : rawPath;
  if (path.length > 1 && path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}
