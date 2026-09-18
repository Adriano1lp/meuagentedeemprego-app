import 'dart:io';
import 'dart:typed_data';

import 'package:agente_emprego/data/api_config.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/services/biometric_preference_store.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/session_test_harness.dart';

void main() {
  late Box<String> sessionBox;
  late Box<MessageModel> chatBox;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('secure_session_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    chatBox = await Hive.openBox<MessageModel>('chat_history');
    sessionBox = await Hive.openBox<String>(SessionStorageKeys.hiveBoxName);
  });

  setUp(() async {
    await chatBox.clear();
    await sessionBox.clear();
  });

  tearDownAll(() async {
    await chatBox.close();
    await sessionBox.close();
  });

  test('saveSession nao grava token em Hive/prefs plaintext', () async {
    final store = bindTestTokenStore();
    final notifier = SessionNotifier(sessionBox, store);
    const token = 'jwt-access-secret-value';

    await notifier.saveSession(
      authToken: token,
      userId: 'user_1',
      email: 'user@example.com',
      displayName: 'Usuario Teste',
      hasCv: false,
    );

    expect(sessionBox.get(SessionStorageKeys.hiveAuthToken), isNull);
    expect(hiveHoldsPlaintextToken(sessionBox, token), isFalse);
    expect(await store.readAccessToken(), token);
    expect(notifier.state.hasSession, isTrue);
    expect(sessionBox.get('user_id'), 'user_1');
  });

  test('logout limpa secure storage e o estado da sessao', () async {
    final store = bindTestTokenStore();
    final notifier = SessionNotifier(sessionBox, store);
    await sessionBox.put(SessionStorageKeys.installMarker, '1');

    await notifier.saveSession(
      authToken: 'logout-token',
      userId: 'user_1',
      email: 'user@example.com',
      displayName: 'Usuario Teste',
      hasCv: true,
    );
    await chatBox.add(
      MessageModel()
        ..id = '1'
        ..text = 'oi'
        ..isUser = true
        ..pdfUrl = null
        ..timestamp = DateTime.now(),
    );

    await notifier.clear();

    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
    expect(notifier.state.hasSession, isFalse);
    expect(sessionBox.get(SessionStorageKeys.hiveAuthToken), isNull);
    expect(sessionBox.get('user_id'), isNull);
    expect(sessionBox.get('email'), isNull);
    expect(chatBox.isEmpty, isTrue);
    expect(sessionBox.get(SessionStorageKeys.installMarker), '1');
  });

  test('lock guarda JWT no cofre e trava a sessao sem plaintext', () async {
    final store = bindTestTokenStore();
    final notifier = SessionNotifier(sessionBox, store);
    const token = 'jwt-locked-in-vault';

    await notifier.saveSession(
      authToken: token,
      userId: 'user_1',
      email: 'user@example.com',
      displayName: 'Usuario Teste',
      hasCv: true,
    );
    await chatBox.add(
      MessageModel()
        ..id = 'kept-after-lock'
        ..text = 'analise anterior'
        ..isUser = false
        ..pdfUrl = null
        ..timestamp = DateTime(2026, 9, 1),
    );
    await notifier.lock();

    expect(await store.hasAccessToken(), isTrue);
    expect(await store.readAccessToken(), isNull);
    expect(store.cachedAccessToken, isNull);
    expect(notifier.state.hasSession, isFalse);
    expect(notifier.state.isLocked, isTrue);
    expect(notifier.state.userId, 'user_1');
    expect(sessionBox.get(SessionNotifier.sessionLockedKey), 'true');
    expect(chatBox.length, 1);
    expect(chatBox.values.first.text, 'analise anterior');
    expect(hiveHoldsPlaintextToken(sessionBox, token), isFalse);
    expect(
      sessionBox.keys.where((key) => key.toString().contains('biometric')),
      isEmpty,
    );

    final revealed = await notifier.revealVaultTokenAfterBiometric();
    expect(revealed, token);
    expect(await store.readAccessToken(), token);
  });

  test('cold start com biometria ativada nao abre sessao automatica', () async {
    final store = MemoryTokenStore(accessToken: 'jwt-cold-start');
    await sessionBox.put(SessionStorageKeys.installMarker, '1');
    await sessionBox.put('user_id', 'user_1');
    await BiometricPreferenceStore(sessionBox).enableForUser('user_1');

    final notifier = SessionNotifier(sessionBox, store);

    expect(await store.hasAccessToken(), isTrue);
    expect(await store.readAccessToken(), isNull);
    expect(store.cachedAccessToken, isNull);
    expect(notifier.state.hasSession, isFalse);
    expect(notifier.state.isLocked, isTrue);
    expect(notifier.state.userId, 'user_1');
    expect(hiveHoldsPlaintextToken(sessionBox, 'jwt-cold-start'), isFalse);
    expect(sessionBox.get('biometric_preference_user_1'), 'enabled');
    expect(hiveHoldsPlaintextToken(sessionBox, 'jwt-cold-start'), isFalse);
  });

  test('reinstall / sessao limpa descarta token residual do cofre', () async {
    final leftover = MemoryTokenStore(accessToken: 'leftover-from-old-install');
    expect(sessionBox.get(SessionStorageKeys.installMarker), isNull);

    await SessionBootstrap.prepare(sessionBox, leftover);

    expect(await leftover.readAccessToken(), isNull);
    expect(sessionBox.get(SessionStorageKeys.installMarker), '1');

    final freshStore = MemoryTokenStore();
    await SessionBootstrap.prepare(sessionBox, freshStore);
    final notifier = SessionNotifier(sessionBox, freshStore);

    expect(await freshStore.readAccessToken(), isNull);
    expect(notifier.state.hasSession, isFalse);
  });

  test('migra auth_token plaintext do Hive para o cofre e apaga o legado', () async {
    final store = MemoryTokenStore();
    await sessionBox.put(SessionStorageKeys.installMarker, '1');
    await sessionBox.put(SessionStorageKeys.hiveAuthToken, 'legacy-hive-token');
    await sessionBox.put('user_id', 'user_9');

    await SessionBootstrap.prepare(sessionBox, store);

    expect(await store.readAccessToken(), 'legacy-hive-token');
    expect(sessionBox.get(SessionStorageKeys.hiveAuthToken), isNull);
    expect(hiveHoldsPlaintextToken(sessionBox, 'legacy-hive-token'), isFalse);
    expect(sessionBox.get('user_id'), 'user_9');
  });

  test('Dio/API le o token do secure storage, nao do Hive', () async {
    final store = MemoryTokenStore(accessToken: 'vault-token');
    await sessionBox.put(SessionStorageKeys.hiveAuthToken, 'hive-plaintext-token');

    late RequestOptions captured;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(SecureAuthInterceptor(store));
    dio.httpClientAdapter = _CaptureAdapter((options) {
      captured = options;
    });

    await dio.get('/secure');

    expect(captured.headers['Authorization'], 'Bearer vault-token');
    expect(captured.headers['Authorization'], isNot(contains('hive-plaintext')));
    expect(
      await resolveBearerHeaders(store, fallbackToken: 'ignored-fallback'),
      {'Authorization': 'Bearer vault-token'},
    );
  });

  test('sessao travada nao envia JWT no Dio e nao grava senha no Hive', () async {
    final store = bindTestTokenStore();
    final notifier = SessionNotifier(sessionBox, store);
    const token = 'jwt-must-not-leave-vault';

    await notifier.saveSession(
      authToken: token,
      userId: 'user_1',
      email: 'user@example.com',
      displayName: 'Usuario Teste',
      hasCv: true,
    );
    await BiometricPreferenceStore(sessionBox).enableForUser('user_1');
    await notifier.lock();

    late RequestOptions captured;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(SecureAuthInterceptor(store));
    dio.httpClientAdapter = _CaptureAdapter((options) {
      captured = options;
    });

    await dio.get('/secure');

    expect(captured.headers['Authorization'], isNull);
    expect(await store.hasAccessToken(), isTrue);
    expect(await store.readAccessToken(), isNull);
    expect(hiveHoldsPlaintextToken(sessionBox, token), isFalse);
    expect(sessionBox.get('biometric_preference_user_1'), 'enabled');
    expect(sessionBox.get('password'), isNull);
    expect(
      sessionBox.values.any((value) => value.contains(token)),
      isFalse,
    );
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.onFetch);

  final void Function(RequestOptions options) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
