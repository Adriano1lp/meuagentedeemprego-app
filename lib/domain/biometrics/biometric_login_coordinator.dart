import '../../data/services/biometric_auth_service.dart';
import '../../data/services/biometric_preference_store.dart';
import '../../data/token_store.dart';

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
    required TokenStore tokenStore,
  }) : _authService = authService,
       _preferenceStore = preferenceStore,
       _tokenStore = tokenStore;

  final BiometricAuthService _authService;
  final BiometricPreferenceStore _preferenceStore;
  final TokenStore _tokenStore;

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

    final hasToken = await _hasVaultToken();
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

    final hasToken = await _hasVaultToken();
    if (!hasToken) {
      return BiometricUnlockResult.missingToken;
    }

    return BiometricUnlockResult.success;
  }

  Future<bool> _hasVaultToken() async {
    final token = await _tokenStore.readAccessToken();
    return token != null && token.trim().isNotEmpty;
  }
}
