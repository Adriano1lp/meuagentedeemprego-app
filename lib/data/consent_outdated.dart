import 'package:dio/dio.dart';

import 'legal_versions.dart';

class ConsentOutdatedException implements Exception {
  final LegalDoc doc;
  final String code;
  final String message;

  const ConsentOutdatedException({
    required this.doc,
    required this.code,
    required this.message,
  });

  static const String termsCode = 'TERMS_OUTDATED';
  static const String privacyCode = 'PRIVACY_OUTDATED';

  static ConsentOutdatedException? fromError(Object error) {
    if (error is ConsentOutdatedException) {
      return error;
    }
    if (error is DioException) {
      return tryParse(error);
    }
    return null;
  }

  static ConsentOutdatedException? tryParse(DioException error) {
    if (error.response?.statusCode != 403) {
      return null;
    }

    return fromPayload(error.response?.data);
  }

  static ConsentOutdatedException? fromPayload(dynamic data) {
    String? code;
    String? message;

    if (data is Map) {
      final detail = data['detail'] ?? data['code'];
      if (detail is Map) {
        code = detail['code']?.toString();
        message = detail['message']?.toString();
      } else if (detail is String) {
        code = _extractCode(detail);
        message = detail;
      } else if (data['code'] is String) {
        code = data['code'] as String;
        message = data['message']?.toString();
      }
    } else if (data is String) {
      code = _extractCode(data);
      message = data;
    }

    return fromCode(code, message: message);
  }

  static ConsentOutdatedException? fromCode(
    String? code, {
    String? message,
  }) {
    final normalized = (code ?? '').trim().toUpperCase();
    if (normalized == termsCode) {
      return ConsentOutdatedException(
        doc: LegalDoc.terms,
        code: termsCode,
        message:
            (message != null && message.trim().isNotEmpty)
            ? message.trim()
            : 'Termos de uso desatualizados. Reaceite a versao vigente.',
      );
    }
    if (normalized == privacyCode) {
      return ConsentOutdatedException(
        doc: LegalDoc.privacy,
        code: privacyCode,
        message:
            (message != null && message.trim().isNotEmpty)
            ? message.trim()
            : 'Politica de privacidade desatualizada. Reaceite a versao vigente.',
      );
    }
    return null;
  }

  static String? _extractCode(String value) {
    if (value.contains(termsCode)) {
      return termsCode;
    }
    if (value.contains(privacyCode)) {
      return privacyCode;
    }
    return value.trim();
  }

  @override
  String toString() => message;
}
