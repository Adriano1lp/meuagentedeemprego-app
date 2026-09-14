import 'package:agente_emprego/data/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug permite http:// para API local', () {
    expect(
      ApiConfig.resolveApiBaseUrl('http://127.0.0.1:8000', isDebug: true),
      'http://127.0.0.1:8000',
    );
  });

  test('build nao-debug bloqueia http://', () {
    expect(
      () => ApiConfig.resolveApiBaseUrl(
        'http://api.meuagentedeemprego.com.br',
        isDebug: false,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('HTTPS'),
        ),
      ),
    );
  });

  test('build nao-debug aceita https://', () {
    expect(
      ApiConfig.resolveApiBaseUrl(
        'https://api.meuagentedeemprego.com.br',
        isDebug: false,
      ),
      'https://api.meuagentedeemprego.com.br',
    );
  });

  test('release bloqueia o default http://127.0.0.1:8000', () {
    expect(
      () => ApiConfig.resolveApiBaseUrl(
        'http://127.0.0.1:8000',
        isDebug: false,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('release sem dart-define usa API de producao HTTPS', () {
    expect(ApiConfig.productionApiBaseUrl, startsWith('https://'));
    expect(
      ApiConfig.resolveApiBaseUrl(
        ApiConfig.productionApiBaseUrl,
        isDebug: false,
      ),
      ApiConfig.productionApiBaseUrl,
    );
    if (ApiConfig.envApiBaseUrl.isEmpty) {
      expect(
        ApiConfig.rawApiBaseUrlFor(isDebug: false),
        ApiConfig.productionApiBaseUrl,
      );
      expect(() => ApiConfig.ensureSafeBaseUrl(isDebug: false), returnsNormally);
    }
  });

  test('debug sem dart-define continua no localhost http', () {
    if (ApiConfig.envApiBaseUrl.isNotEmpty) {
      return;
    }
    expect(
      ApiConfig.rawApiBaseUrlFor(isDebug: true),
      ApiConfig.debugDefaultApiBaseUrl,
    );
  });

  test('release ainda recusa http mesmo com fallback de producao', () {
    expect(
      () => ApiConfig.resolveApiBaseUrl(
        ApiConfig.debugDefaultApiBaseUrl,
        isDebug: false,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('logger de debug nao imprime headers nem body (sem JWT)', () {
    expect(createSafeDebugLogInterceptor(isDebug: false), isNull);

    final interceptor = createSafeDebugLogInterceptor(isDebug: true);
    expect(interceptor, isNotNull);
    expect(interceptor!.requestHeader, isFalse);
    expect(interceptor.requestBody, isFalse);
    expect(interceptor.responseHeader, isFalse);
    expect(interceptor.responseBody, isFalse);
  });
}
