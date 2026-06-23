import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/services/biometric_auth_service.dart';
import '../../data/services/biometric_preference_store.dart';
import '../../domain/biometrics/biometric_login_coordinator.dart';
import 'session_provider.dart';

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return LocalBiometricAuthService();
});

final biometricPreferenceStoreProvider = Provider<BiometricPreferenceStore>((
  ref,
) {
  return BiometricPreferenceStore(Hive.box<String>('app_session'));
});

final biometricLoginCoordinatorProvider = Provider<BiometricLoginCoordinator>((
  ref,
) {
  return BiometricLoginCoordinator(
    authService: ref.watch(biometricAuthServiceProvider),
    preferenceStore: ref.watch(biometricPreferenceStoreProvider),
    tokenStore: ref.watch(sessionTokenStoreProvider),
  );
});
