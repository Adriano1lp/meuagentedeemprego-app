import 'dart:typed_data';

import 'package:agente_emprego/data/cv_file_name.dart';
import 'package:agente_emprego/data/repositories/cv_file_repository.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeCvFileName', () {
    test('aceita basename simples', () {
      expect(sanitizeCvFileName('cv_otimizado.pdf'), 'cv_otimizado.pdf');
      expect(sanitizeCvFileName('  CV-1.pdf  '), 'CV-1.pdf');
    });

    test('rejeita vazio, traversal e barras', () {
      expect(sanitizeCvFileName(null), isNull);
      expect(sanitizeCvFileName(''), isNull);
      expect(sanitizeCvFileName('   '), isNull);
      expect(sanitizeCvFileName('..'), isNull);
      expect(sanitizeCvFileName('../segredo.pdf'), isNull);
      expect(sanitizeCvFileName('pasta/cv.pdf'), isNull);
      expect(sanitizeCvFileName(r'pasta\cv.pdf'), isNull);
      expect(sanitizeCvFileName('%2e%2e%2fsegredo.pdf'), isNull);
    });
  });

  group('CvFileRepository.downloadBytes', () {
    test('C3 GET /users/me/files/{nome} so com Bearer', () async {
      final store = MemoryTokenStore(accessToken: 'jwt-cv-secret');
      late RequestOptions captured;
      final pdf = Uint8List.fromList('%PDF-1.4'.codeUnits);
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://example.test',
          headers: {'X-User-Id': 'outra-conta'},
        ),
      );
      dio.httpClientAdapter = _BytesAdapter(
        onFetch: (options) => captured = options,
        bytes: pdf,
      );

      final bytes = await CvFileRepository(
        dio: dio,
        tokenStore: store,
      ).downloadBytes('cv_otimizado.pdf');

      expect(captured.method, 'GET');
      expect(captured.path, '/users/me/files/cv_otimizado.pdf');
      expect(captured.uri.path, '/users/me/files/cv_otimizado.pdf');
      expect(captured.headers['Authorization'], 'Bearer jwt-cv-secret');
      expect(captured.headers['X-User-Id'], isNull);
      expect(captured.headers['x-user-id'], isNull);
      expect(bytes, pdf);
      expect(await store.readAccessToken(), 'jwt-cv-secret');
    });

    test('nome inseguro ou sem JWT nao chama a rede', () async {
      var called = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _BytesAdapter(
        onFetch: (_) => called = true,
        bytes: Uint8List.fromList([1]),
      );

      final repository = CvFileRepository(
        dio: dio,
        tokenStore: MemoryTokenStore(accessToken: 'jwt-cv-secret'),
      );

      await expectLater(
        repository.downloadBytes('../cv.pdf'),
        throwsA(isA<CvDownloadException>()),
      );
      await expectLater(
        CvFileRepository(
          dio: dio,
          tokenStore: MemoryTokenStore(),
        ).downloadBytes('cv.pdf'),
        throwsA(isA<CvDownloadException>()),
      );
      expect(called, isFalse);
    });

    test('C4 erro HTTP vira mensagem fixa sem token, path ou HTML', () async {
      final store = MemoryTokenStore(accessToken: 'jwt-should-not-leak');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _BytesAdapter(
        onFetch: (_) {},
        bytes: Uint8List(0),
        statusCode: 500,
        bodyText:
            '<html>Bearer jwt-should-not-leak /users/me/files/cv.pdf stack',
      );

      try {
        await CvFileRepository(
          dio: dio,
          tokenStore: store,
        ).downloadBytes('cv_otimizado.pdf');
        fail('esperava CvDownloadException');
      } on CvDownloadException catch (error) {
        expect(error.toString(), cvDownloadFailedMessage);
        expect(error.toString(), isNot(contains('jwt-should-not-leak')));
        expect(error.toString(), isNot(contains('Bearer')));
        expect(error.toString(), isNot(contains('<html>')));
        expect(error.toString(), isNot(contains('/users/me/files')));
        expect(error.toString(), isNot(contains('stack')));
      }
    });
  });
}

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter({
    required this.onFetch,
    required this.bytes,
    this.statusCode = 200,
    this.bodyText = '',
  });

  final void Function(RequestOptions options) onFetch;
  final Uint8List bytes;
  final int statusCode;
  final String bodyText;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch(options);
    if (statusCode >= 400) {
      return ResponseBody.fromString(
        bodyText,
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      );
    }
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/pdf'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
