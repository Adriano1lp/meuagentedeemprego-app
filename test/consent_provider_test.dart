import 'package:agente_emprego/data/consent_outdated.dart';
import 'package:agente_emprego/data/legal_versions.dart';
import 'package:agente_emprego/presentation/providers/consent_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compara versoes do usuario com as vigentes no client', () {
    final notifier = ConsentNotifier();

    notifier.applyFromUser(termsVersion: '0.9', privacyVersion: '1.0');
    expect(notifier.state.termsOutdated, isTrue);
    expect(notifier.state.privacyOutdated, isFalse);
    expect(notifier.state.blocksApp, isTrue);
    expect(notifier.state.outdatedDocs, [LegalDoc.terms]);

    notifier.applyFromUser(
      termsVersion: CURRENT_TERMS_VERSION,
      privacyVersion: CURRENT_PRIVACY_VERSION,
    );
    expect(notifier.state.blocksApp, isFalse);
  });

  test('acumula TERMS_OUTDATED e PRIVACY_OUTDATED', () {
    final notifier = ConsentNotifier();

    notifier.applyException(
      const ConsentOutdatedException(
        doc: LegalDoc.terms,
        code: ConsentOutdatedException.termsCode,
        message: 'termos',
      ),
    );
    notifier.applyException(
      const ConsentOutdatedException(
        doc: LegalDoc.privacy,
        code: ConsentOutdatedException.privacyCode,
        message: 'privacidade',
      ),
    );

    expect(notifier.state.termsOutdated, isTrue);
    expect(notifier.state.privacyOutdated, isTrue);
    expect(notifier.state.outdatedDocs, [LegalDoc.terms, LegalDoc.privacy]);

    notifier.markAccepted(LegalDoc.terms);
    expect(notifier.state.termsOutdated, isFalse);
    expect(notifier.state.privacyOutdated, isTrue);
  });
}
