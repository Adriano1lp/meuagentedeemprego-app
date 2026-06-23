import '../../data/services/biometric_auth_service.dart';
import '../../data/services/biometric_preference_store.dart';
import '../../data/services/session_token_store.dart';

enum BiometricUnlockResult {
  success,
  unavailable,
  cancelled,
  missingToken,
}

class BiometricLoginCoordinator {
  BiometricLoginCoordinator({
    required BiometricAuthService authService,
    required BiometricPreferenceStore preferenceStore,
    required SessionTokenStore tokenStore,
  }) : _authService = authService,
       _preferenceStore = preferenceStore,
       _tokenStore = tokenStore;

  final BiometricAuthService _authService;
  final BiometricPreferenceStore _preferenceStore;
  final SessionTokenStore _tokenStore;

  Future<bool> shouldPromptAfterPasswordLogin(String userId) async {
    if (_preferenceStore.statusForUser(userId) !=
        BiometricPreferenceStatus.unknown) {
      return false;
    }

    return _authService.canUseBiometrics();
  }

  Future<bool> canUseBiometricLogin(String userId) async {
    if (_preferenceStore.statusForUser(userId) !=
        BiometricPreferenceStatus.enabled) {
      return false;
    }

    final hasToken = await _tokenStore.hasToken();
    if (!hasToken) {
      return false;
    }

    return _authService.canUseBiometrics();
  }

  Future<BiometricUnlockResult> unlock({
    required String reason,
  }) async {
    final canUse = await _authService.canUseBiometrics();
    if (!canUse) {
      return BiometricUnlockResult.unavailable;
    }

    final authenticated = await _authService.authenticate(reason: reason);
    if (!authenticated) {
      return BiometricUnlockResult.cancelled;
    }

    final hasToken = await _tokenStore.hasToken();
    if (!hasToken) {
      return BiometricUnlockResult.missingToken;
    }

    return BiometricUnlockResult.success;
  }
}
