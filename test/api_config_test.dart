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
}
