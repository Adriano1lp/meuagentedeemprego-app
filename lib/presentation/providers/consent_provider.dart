import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/consent_outdated.dart';
import '../../data/legal_versions.dart';

final consentProvider =
    StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
      return ConsentNotifier();
    });

class ConsentState {
  final bool termsOutdated;
  final bool privacyOutdated;

  const ConsentState({
    this.termsOutdated = false,
    this.privacyOutdated = false,
  });

  bool get blocksApp => termsOutdated || privacyOutdated;

  List<LegalDoc> get outdatedDocs => [
    if (termsOutdated) LegalDoc.terms,
    if (privacyOutdated) LegalDoc.privacy,
  ];

  ConsentState copyWith({
    bool? termsOutdated,
    bool? privacyOutdated,
  }) {
    return ConsentState(
      termsOutdated: termsOutdated ?? this.termsOutdated,
      privacyOutdated: privacyOutdated ?? this.privacyOutdated,
    );
  }
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  ConsentNotifier() : super(const ConsentState());

  void applyFromUser({
    required String? termsVersion,
    required String? privacyVersion,
  }) {
    state = ConsentState(
      termsOutdated: !isCurrentTermsVersion(termsVersion),
      privacyOutdated: !isCurrentPrivacyVersion(privacyVersion),
    );
  }

  void applyException(ConsentOutdatedException error) {
    state = state.copyWith(
      termsOutdated: error.doc == LegalDoc.terms ? true : state.termsOutdated,
      privacyOutdated: error.doc == LegalDoc.privacy
          ? true
          : state.privacyOutdated,
    );
  }

  void applyIfOutdated(Object error) {
    final parsed = ConsentOutdatedException.fromError(error);
    if (parsed != null) {
      applyException(parsed);
    }
  }

  void markAccepted(LegalDoc doc) {
    state = state.copyWith(
      termsOutdated: doc == LegalDoc.terms ? false : state.termsOutdated,
      privacyOutdated: doc == LegalDoc.privacy ? false : state.privacyOutdated,
    );
  }

  void clear() {
    state = const ConsentState();
  }
}
