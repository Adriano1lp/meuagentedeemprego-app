/// Versoes vigentes alinhadas com a API (`CURRENT_TERMS_VERSION` / `CURRENT_PRIVACY_VERSION`).
// ignore: constant_identifier_names
const String CURRENT_TERMS_VERSION = '1.0';
// ignore: constant_identifier_names
const String CURRENT_PRIVACY_VERSION = '1.0';

enum LegalDoc {
  terms,
  privacy;

  String get apiValue => name;

  String get currentVersion =>
      this == LegalDoc.terms ? CURRENT_TERMS_VERSION : CURRENT_PRIVACY_VERSION;

  String get title =>
      this == LegalDoc.terms ? 'Termos de uso' : 'Politica de privacidade';

  String get acceptPrefix =>
      this == LegalDoc.terms ? 'Li e aceito os ' : 'Li e aceito a ';

  String get outdatedCode =>
      this == LegalDoc.terms ? 'TERMS_OUTDATED' : 'PRIVACY_OUTDATED';
}

bool isCurrentTermsVersion(String? version) =>
    (version ?? '').trim() == CURRENT_TERMS_VERSION;

bool isCurrentPrivacyVersion(String? version) =>
    (version ?? '').trim() == CURRENT_PRIVACY_VERSION;

Map<String, dynamic> buildRegisterConsentFields({
  required bool termsAccepted,
  required bool privacyAccepted,
}) {
  return {
    'terms_accepted': termsAccepted,
    'terms_version': CURRENT_TERMS_VERSION,
    'privacy_accepted': privacyAccepted,
    'privacy_version': CURRENT_PRIVACY_VERSION,
  };
}
