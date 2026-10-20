import 'package:agente_emprego/data/api_errors.dart';
import 'package:agente_emprego/data/session_unauthorized.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractApiErrorMessage', () {
    test('usa detail string FastAPI com status HTTP', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/processar'),
        response: Response(
          requestOptions: RequestOptions(path: '/processar'),
          statusCode: 400,
          data: {
            'detail':
                'Embeddings do usuario nao encontrados. Envie o curriculo e execute POST /users/me/rebuild-embeddings antes de processar a vaga.',
          },
        ),
      );

      expect(
        extractApiErrorMessage(error, fallback: 'Falha ao conectar com a API'),
        'HTTP 400: Embeddings do usuario nao encontrados. Envie o curriculo e execute POST /users/me/rebuild-embeddings antes de processar a vaga.',
      );
    });

    test('402 ignora o corpo e usa a frase neutra de limite', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/processar'),
        response: Response(
          requestOptions: RequestOptions(path: '/processar'),
          statusCode: 402,
          data: {
            'detail': {
              'code': 'SUBSCRIPTION_REQUIRED',
              'message':
                  'Cota gratuita do mes esgotada. Assine em https://example.test/checkout por R\$ 29.',
              'used': 5,
              'limit': 5,
              'plan': 'free',
              'checkout_url': 'https://example.test/checkout',
            },
          },
        ),
      );

      expect(
        extractApiErrorMessage(error, fallback: 'Falha ao conectar com a API'),
        monthlyQuotaLimitMessage,
      );
    });

    test('402 sem detail tambem usa a frase neutra', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/users/me/cover-letter'),
        response: Response(
          requestOptions: RequestOptions(path: '/users/me/cover-letter'),
          statusCode: 402,
          data: null,
        ),
      );

      expect(
        extractApiErrorMessage(
          error,
          fallback: 'Falha ao gerar carta de apresentacao',
        ),
        monthlyQuotaLimitMessage,
      );
    });

    test('usa msg da lista de validacao FastAPI', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/processar'),
        response: Response(
          requestOptions: RequestOptions(path: '/processar'),
          statusCode: 422,
          data: {
            'detail': [
              {
                'loc': ['body', 'texto'],
                'msg': 'Field required',
                'type': 'missing',
              },
            ],
          },
        ),
      );

      expect(
        extractApiErrorMessage(error, fallback: 'Falha ao conectar com a API'),
        'HTTP 422: Field required',
      );
    });

    test('401 com Bearer vira sessao expirada, sem o detail da API', () {
      final error = _unauthorized('/auth/me', 'Token expirado');

      expect(
        extractApiErrorMessage(
          error,
          fallback: 'Falha ao autenticar com a API',
        ),
        sessionExpiredMessage,
      );
      expect(
        () => rethrowApiError(error, fallback: 'Falha ao autenticar com a API'),
        throwsA(
          isA<SessionExpiredException>().having(
            (error) => error.toString(),
            'toString',
            sessionExpiredMessage,
          ),
        ),
      );
    });

    test('401 de login continua erro de credencial', () {
      final error = _unauthorized('/auth/login', 'Email ou senha invalidos');

      expect(
        extractApiErrorMessage(
          error,
          fallback: 'Falha ao autenticar com a API',
        ),
        'HTTP 401: Email ou senha invalidos',
      );
      expect(
        () => rethrowApiError(error, fallback: 'Falha ao autenticar com a API'),
        throwsA(
          allOf(
            isA<Exception>(),
            isNot(isA<SessionExpiredException>()),
            predicate<Exception>(
              (error) =>
                  error.toString() ==
                  'Exception: HTTP 401: Email ou senha invalidos',
            ),
          ),
        ),
      );
    });

    test('401 sem Bearer nao encerra sessao', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/users/me/status'),
        response: Response(
          requestOptions: RequestOptions(path: '/users/me/status'),
          statusCode: 401,
          data: {'detail': 'Header Authorization obrigatorio'},
        ),
      );

      expect(
        extractApiErrorMessage(
          error,
          fallback: 'Falha ao autenticar com a API',
        ),
        'HTTP 401: Header Authorization obrigatorio',
      );
    });

    test('receiveTimeout nao vira falha generica', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/processar'),
        type: DioExceptionType.receiveTimeout,
      );

      expect(
        extractApiErrorMessage(error, fallback: 'Falha ao conectar com a API'),
        'A analise demorou demais. Tente novamente.',
      );
    });
  });
}

DioException _unauthorized(String path, String detail) {
  final options = RequestOptions(
    path: path,
    headers: {'Authorization': 'Bearer jwt-velho'},
  );
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: 401,
      data: {'detail': detail},
    ),
  );
}
