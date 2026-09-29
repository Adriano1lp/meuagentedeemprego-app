import 'package:agente_emprego/data/repositories/cover_letter_repository_impl.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryTokenStore tokenStore;

  setUp(() {
    tokenStore = MemoryTokenStore(accessToken: 'token');
  });

  CoverLetterRepositoryImpl repositoryFor(Dio dio) {
    return CoverLetterRepositoryImpl(dio: dio, tokenStore: tokenStore);
  }

  Dio dioThatRejects({required int statusCode, required dynamic data}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: statusCode,
                data: data,
              ),
            ),
          );
        },
      ),
    );
    return dio;
  }

  test('200 devolve o texto da carta sem alterar o fluxo', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/users/me/cover-letter');
          expect(options.data, {'empresa': 'Nexa Talent'});
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'texto_resposta': 'Carta para a Nexa',
                'pdf_url': 'https://example.test/carta.pdf',
              },
            ),
          );
        },
      ),
    );

    final message = await repositoryFor(dio).generateCoverLetter(
      companyName: 'Nexa Talent',
      authToken: 'token',
    );

    expect(message.text, 'Carta para a Nexa');
    expect(message.pdfUrl, 'https://example.test/carta.pdf');
    expect(message.isUser, isFalse);
  });

  test('402 mostra detail.message da cota', () async {
    final repository = repositoryFor(
      dioThatRejects(
        statusCode: 402,
        data: {
          'detail': {
            'code': 'SUBSCRIPTION_REQUIRED',
            'message': 'Cota gratuita do mes esgotada.',
          },
        },
      ),
    );

    expect(
      () => repository.generateCoverLetter(
        companyName: 'Nexa Talent',
        authToken: 'token',
      ),
      throwsA(
        _readableDetail('HTTP 402: Cota gratuita do mes esgotada.'),
      ),
    );
  });

  test('422 mostra detail string de parse invalido', () async {
    final repository = repositoryFor(
      dioThatRejects(
        statusCode: 422,
        data: {
          'detail': 'Nao foi possivel validar os dados enviados.',
        },
      ),
    );

    expect(
      () => repository.generateCoverLetter(
        companyName: 'Nexa Talent',
        authToken: 'token',
      ),
      throwsA(
        _readableDetail('HTTP 422: Nao foi possivel validar os dados enviados.'),
      ),
    );
  });

  test('422 mostra msg da lista de validacao FastAPI', () async {
    final repository = repositoryFor(
      dioThatRejects(
        statusCode: 422,
        data: {
          'detail': [
            {
              'loc': ['body', 'empresa'],
              'msg': 'Field required',
              'type': 'missing',
            },
          ],
        },
      ),
    );

    expect(
      () => repository.generateCoverLetter(
        companyName: 'Nexa Talent',
        authToken: 'token',
      ),
      throwsA(_readableDetail('HTTP 422: Field required')),
    );
  });
}

Matcher _readableDetail(String message) {
  return predicate<Object>((error) {
    final text = error.toString();
    return text.contains(message) &&
        !text.toLowerCase().contains('desconhecido') &&
        !text.contains('Erro inesperado');
  }, 'erro legivel "$message"');
}
