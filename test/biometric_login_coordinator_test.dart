import 'dart:io';

import 'package:agente_emprego/data/services/biometric_auth_service.dart';
import 'package:agente_emprego/data/services/biometric_preference_store.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/domain/biometrics/biometric_login_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Box<String> box;
  late BiometricPreferenceStore preferences;
  late _FakeBiometricAuthService authService;
  late MemoryTokenStore tokenStore;
  late BiometricLoginCoordinator coordinator;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'biometric_login_test',
    );
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('biometric_login_test');
  });

  setUp(() async {
    await box.clear();
    preferences = BiometricPreferenceStore(box);
    authService = _FakeBiometricAuthService();
    tokenStore = MemoryTokenStore();
    coordinator = BiometricLoginCoordinator(
      authService: authService,
      preferenceStore: preferences,
      tokenStore: tokenStore,
    );
  });

  tearDownAll(() async {
    await box.close();
  });

  test('pergunta apos login quando dispositivo tem biometria e usuario nao decidiu', () async {
    authService.canUse = true;

    final shouldPrompt = await coordinator.shouldPromptAfterPasswordLogin(
      'user_1',
    );

    expect(shouldPrompt, isTrue);
  });

  test('nao pergunta em dispositivo sem biometria', () async {
    authService.canUse = false;

    final shouldPrompt = await coordinator.shouldPromptAfterPasswordLogin(
      'user_1',
    );

    expect(shouldPrompt, isFalse);
  });

  test('nao pergunta novamente quando usuario recusou biometria', () async {
    authService.canUse = true;
    await preferences.declineForUser('user_1');

    final shouldPrompt = await coordinator.shouldPromptAfterPasswordLogin(
      'user_1',
    );

    expect(shouldPrompt, isFalse);
  });

  test('permite login biometrico quando usuario aceitou e JWT esta no cofre', () async {
    authService.canUse = true;
    await tokenStore.writeAccessToken('jwt-in-vault');
    await preferences.enableForUser('user_1');

    final canLogin = await coordinator.canUseBiometricLogin('user_1');

    expect(canLogin, isTrue);
  });

  test('nao oferece biometria se o JWT nao esta no cofre', () async {
    authService.canUse = true;
    await preferences.enableForUser('user_1');

    final canLogin = await coordinator.canUseBiometricLogin('user_1');

    expect(canLogin, isFalse);
  });

  test('falha de biometria retorna cancelado para fallback manual', () async {
    authService.canUse = true;
    authService.authenticated = false;
    await tokenStore.writeAccessToken('token');

    final result = await coordinator.unlock(reason: 'Entrar');

    expect(result, BiometricUnlockResult.cancelled);
  });

  test('biometria aprovada sem token no cofre retorna sessao expirada', () async {
    authService.canUse = true;
    authService.authenticated = true;

    final result = await coordinator.unlock(reason: 'Entrar');

    expect(result, BiometricUnlockResult.missingToken);
  });
}

class _FakeBiometricAuthService implements BiometricAuthService {
  bool canUse = false;
  bool authenticated = true;

  @override
  Future<bool> authenticate({
    required String reason,
  }) async {
    return authenticated;
  }

  @override
  Future<bool> canUseBiometrics() async {
    return canUse;
  }
}
