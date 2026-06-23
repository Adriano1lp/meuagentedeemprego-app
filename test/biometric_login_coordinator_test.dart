import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:meu_agente_de_emprego/data/services/biometric_auth_service.dart';
import 'package:meu_agente_de_emprego/data/services/biometric_preference_store.dart';
import 'package:meu_agente_de_emprego/data/services/session_token_store.dart';
import 'package:meu_agente_de_emprego/domain/biometrics/biometric_login_coordinator.dart';

void main() {
  late Box<String> box;
  late BiometricPreferenceStore preferences;
  late _FakeBiometricAuthService authService;
  late _FakeSessionTokenStore tokenStore;
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
    tokenStore = _FakeSessionTokenStore();
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

  test('permite login biometrico quando usuario aceitou e token existe', () async {
    authService.canUse = true;
    tokenStore.token = 'token';
    await preferences.enableForUser('user_1');

    final canLogin = await coordinator.canUseBiometricLogin('user_1');

    expect(canLogin, isTrue);
  });

  test('falha de biometria retorna cancelado para fallback manual', () async {
    authService.canUse = true;
    authService.authenticated = false;
    tokenStore.token = 'token';

    final result = await coordinator.unlock(reason: 'Entrar');

    expect(result, BiometricUnlockResult.cancelled);
  });

  test('biometria aprovada sem token retorna sessao expirada', () async {
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

class _FakeSessionTokenStore implements SessionTokenStore {
  String? token;

  @override
  Future<void> deleteToken() async {
    token = null;
  }

  @override
  Future<String?> readToken() async {
    return token;
  }

  @override
  Future<void> saveToken(String token) async {
    this.token = token;
  }

  @override
  Future<bool> hasToken() async {
    return token != null && token!.trim().isNotEmpty;
  }
}
