import 'package:agente_emprego/data/api_errors.dart';
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

    test('usa detail.message de cota 402', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/processar'),
        response: Response(
          requestOptions: RequestOptions(path: '/processar'),
          statusCode: 402,
          data: {
            'detail': {
              'code': 'SUBSCRIPTION_REQUIRED',
              'message': 'Cota gratuita do mes esgotada.',
              'used': 5,
              'limit': 5,
              'plan': 'free',
            },
          },
        ),
      );

      expect(
        extractApiErrorMessage(error, fallback: 'Falha ao conectar com a API'),
        'HTTP 402: Cota gratuita do mes esgotada.',
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
