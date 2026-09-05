import 'package:agente_emprego/data/consent_outdated.dart';
import 'package:agente_emprego/data/legal_versions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildRegisterConsentFields', () {
    test('envia os 4 campos com versoes vigentes 1.0', () {
      final payload = buildRegisterConsentFields(
        termsAccepted: true,
        privacyAccepted: true,
      );

      expect(payload, {
        'terms_accepted': true,
        'terms_version': CURRENT_TERMS_VERSION,
        'privacy_accepted': true,
        'privacy_version': CURRENT_PRIVACY_VERSION,
      });
      expect(CURRENT_TERMS_VERSION, '1.0');
      expect(CURRENT_PRIVACY_VERSION, '1.0');
    });
  });

  group('ConsentOutdatedException', () {
    test('parseia 403 com detail.code TERMS_OUTDATED', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 403,
          data: {
            'detail': {
              'code': 'TERMS_OUTDATED',
              'message': 'Termos de uso desatualizados. Reaceite a versao vigente.',
            },
          },
        ),
      );

      final parsed = ConsentOutdatedException.tryParse(error);
      expect(parsed, isNotNull);
      expect(parsed!.doc, LegalDoc.terms);
      expect(parsed.code, 'TERMS_OUTDATED');
    });

    test('parseia 403 com detail.code PRIVACY_OUTDATED', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/users/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/users/me'),
          statusCode: 403,
          data: {
            'detail': {
              'code': 'PRIVACY_OUTDATED',
              'message': 'Politica de privacidade desatualizada.',
            },
          },
        ),
      );

      final parsed = ConsentOutdatedException.tryParse(error);
      expect(parsed, isNotNull);
      expect(parsed!.doc, LegalDoc.privacy);
      expect(parsed.code, 'PRIVACY_OUTDATED');
    });

    test('parseia 403 com detail string', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/processar'),
        response: Response(
          requestOptions: RequestOptions(path: '/processar'),
          statusCode: 403,
          data: {'detail': 'TERMS_OUTDATED'},
        ),
      );

      final parsed = ConsentOutdatedException.tryParse(error);
      expect(parsed?.code, 'TERMS_OUTDATED');
    });

    test('ignora 403 generico', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/users/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/users/me'),
          statusCode: 403,
          data: {'detail': 'Sem permissao'},
        ),
      );

      expect(ConsentOutdatedException.tryParse(error), isNull);
    });

    test('ignora status diferente de 403', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 401,
          data: {
            'detail': {'code': 'TERMS_OUTDATED'},
          },
        ),
      );

      expect(ConsentOutdatedException.tryParse(error), isNull);
    });
  });
}
