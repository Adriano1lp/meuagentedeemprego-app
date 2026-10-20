import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agente_emprego/data/api_config.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/services/biometric_auth_service.dart';
import 'package:agente_emprego/data/services/biometric_preference_store.dart';
import 'package:agente_emprego/data/session_unauthorized.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/main.dart';
import 'package:agente_emprego/presentation/app_navigator.dart';
import 'package:agente_emprego/presentation/providers/biometric_providers.dart';
import 'package:agente_emprego/presentation/utils/authenticated_pdf_opener.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/session_test_harness.dart';

void main() {
  late MemoryTokenStore tokenStore;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('sessao_401_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    if (!Hive.isBoxOpen('chat_history')) {
      await Hive.openBox<MessageModel>('chat_history', bytes: Uint8List(0));
    }
    if (!Hive.isBoxOpen('app_session')) {
      await Hive.openBox<String>('app_session', bytes: Uint8List(0));
    }
  });

  setUp(() async {
    tokenStore = bindTestTokenStore();
    await Hive.box<MessageModel>('chat_history').clear();
    await Hive.box<String>('app_session').clear();
  });

  tearDownAll(() async {
    await Hive.box<MessageModel>('chat_history').close();
    await Hive.box<String>('app_session').close();
  });

  group('interceptor', () {
    test('varios 401 ao mesmo tempo encerram a sessao uma unica vez', () async {
      final store = MemoryTokenStore(accessToken: 'jwt-velho');
      final gate = Completer<void>();
      final started = Completer<void>();
      var calls = 0;
      bindUnauthorizedSessionHandler(() {
        calls += 1;
        if (!started.isCompleted) {
          started.complete();
        }
        return gate.future;
      });
      final dio = _dioThatFails(store);

      final first = _ignoreDio(dio.get('/processar'));
      final second = _ignoreDio(dio.get('/users/me/status'));
      await started.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue(times: 20);

      expect(calls, 1);
      gate.complete();
      await Future.wait([first, second]);
      expect(calls, 1);

      resetUnauthorizedSessionHandling();
      await _ignoreDio(dio.get('/users/me/gap-history'));
      expect(calls, 2);
    });

    test('401 de login e cadastro nao apaga o Bearer', () async {
      final store = MemoryTokenStore(accessToken: 'jwt-velho');
      var calls = 0;
      bindUnauthorizedSessionHandler(() async {
        calls += 1;
      });
      final dio = _dioThatFails(store, detail: 'Email ou senha invalidos');

      await _ignoreDio(dio.post('/auth/login'));
      await _ignoreDio(dio.post('/auth/register'));

      expect(calls, 0);
      expect(await store.readAccessToken(), 'jwt-velho');
    });

    test('401 sem Bearer e 403 nao encerram a sessao', () async {
      final store = MemoryTokenStore();
      var calls = 0;
      bindUnauthorizedSessionHandler(() async {
        calls += 1;
      });
      final dio = _dioThatFails(store);

      await _ignoreDio(dio.get('/users/me/status'));
      expect(calls, 0);

      final withToken = MemoryTokenStore(accessToken: 'jwt-velho');
      final forbidden = _dioThatFails(withToken, statusCode: 403);
      await _ignoreDio(forbidden.get('/users/me/status'));
      expect(calls, 0);
      expect(await withToken.readAccessToken(), 'jwt-velho');
    });
  });

  test('download de PDF com Bearer vencido usa a frase de sessao', () {
    final options = RequestOptions(
      path: '/users/me/files/carta.pdf',
      headers: {'Authorization': 'Bearer jwt-velho'},
    );
    expect(
      authenticatedPdfDownloadMessage(
        DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 401,
            data: {'detail': 'JWT invalido'},
          ),
        ),
      ),
      sessionExpiredMessage,
    );
  });

  testWidgets('401 na abertura leva ao login e apaga o token', (tester) async {
    await _prepareSurface(tester);
    await _seedOpenSession(tokenStore);
    bindApiHttpClientAdapter(
      _ScriptedAdapter(
        (options) async => _json(401, {'detail': 'Token expirado'}),
      ),
    );

    await tester.pumpWidget(_app(tokenStore));
    await _pumpApp(tester);

    expect(find.text('Entrar na conta'), findsOneWidget);
    expect(find.text(sessionExpiredMessage), findsOneWidget);
    expect(find.textContaining('HTTP 401'), findsNothing);
    expect(await tokenStore.hasAccessToken(), isFalse);
    expect(Hive.box<String>('app_session').get('user_id'), isNull);
    expect(appNavigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('401 durante o uso abre o login uma vez', (tester) async {
    await _prepareSurface(tester);
    await _seedOpenSession(tokenStore);
    var expirar = false;
    bindApiHttpClientAdapter(
      _ScriptedAdapter((options) async {
        final path = options.uri.path;
        if (!expirar &&
            (path.endsWith('/auth/me') || path.endsWith('/users/me/status'))) {
          return path.endsWith('/auth/me')
              ? _json(200, _userBody)
              : _json(200, _statusBody);
        }
        return _json(401, {'detail': 'JWT invalido'});
      }),
    );

    await tester.pumpWidget(_app(tokenStore));
    await _pumpApp(tester);
    expect(find.text('Ola, Ana'), findsOneWidget);

    expirar = true;
    await tester.ensureVisible(find.text('Historico'));
    await tester.tap(find.text('Historico'));
    await _pumpApp(tester);

    expect(find.text('Entrar na conta'), findsOneWidget);
    expect(find.text('Historico'), findsNothing);
    expect(find.text(sessionExpiredMessage), findsOneWidget);
    expect(find.textContaining('HTTP 401'), findsNothing);
    expect(await tokenStore.hasAccessToken(), isFalse);
    expect(appNavigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('401 no login continua erro de credencial', (tester) async {
    await _prepareSurface(tester);
    bindApiHttpClientAdapter(
      _ScriptedAdapter(
        (options) async => _json(401, {'detail': 'Email ou senha invalidos'}),
      ),
    );

    await tester.pumpWidget(_app(tokenStore));
    await _pumpApp(tester);

    await tester.enterText(find.byType(TextField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'senha-errada');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await _pumpApp(tester);

    expect(find.text('Entrar na conta'), findsOneWidget);
    expect(find.text('HTTP 401: Email ou senha invalidos'), findsOneWidget);
    expect(find.text(sessionExpiredMessage), findsNothing);
    expect(await tokenStore.hasAccessToken(), isFalse);
    expect(appNavigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('biometria com token invalido nao deixa o usuario preso', (
    tester,
  ) async {
    await _prepareSurface(tester);
    await _seedOpenSession(tokenStore, biometria: true);
    bindApiHttpClientAdapter(
      _ScriptedAdapter(
        (options) async => _json(401, {'detail': 'JWT invalido'}),
      ),
    );

    await tester.pumpWidget(
      _app(
        tokenStore,
        overrides: [
          biometricAuthServiceProvider.overrideWithValue(_BiometriaAprovada()),
        ],
      ),
    );
    await _pumpApp(tester);

    expect(find.byKey(const ValueKey('biometricLoginButton')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('biometricLoginButton')));
    await _pumpApp(tester);

    expect(find.text('Entrar na conta'), findsOneWidget);
    expect(find.text('Acessar conta existente'), findsOneWidget);
    expect(find.text(sessionExpiredMessage), findsOneWidget);
    expect(find.textContaining('HTTP 401'), findsNothing);
    expect(find.text('Validando biometria...'), findsNothing);
    expect(find.byKey(const ValueKey('biometricLoginButton')), findsNothing);
    expect(await tokenStore.hasAccessToken(), isFalse);
    expect(appNavigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('depois de entrar de novo o proximo 401 encerra outra vez', (
    tester,
  ) async {
    await _prepareSurface(tester);
    await _seedOpenSession(tokenStore);
    var fase = _FaseApi.tokenVencido;
    bindApiHttpClientAdapter(
      _ScriptedAdapter((options) async {
        final path = options.uri.path;
        if (path.endsWith('/auth/login')) {
          return _json(200, _loginBody);
        }
        if (fase == _FaseApi.sessaoNova &&
            (path.endsWith('/auth/me') || path.endsWith('/users/me/status'))) {
          return path.endsWith('/auth/me')
              ? _json(200, _userBody)
              : _json(200, _statusBody);
        }
        return _json(401, {'detail': 'Token expirado'});
      }),
    );

    await tester.pumpWidget(_app(tokenStore));
    await _pumpApp(tester);
    expect(find.text(sessionExpiredMessage), findsOneWidget);

    fase = _FaseApi.sessaoNova;
    await tester.enterText(find.byType(TextField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'senha-certa-12');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await _pumpApp(tester);
    expect(find.text('Ola, Ana'), findsOneWidget);
    expect(await tokenStore.readAccessToken(), 'jwt-novo');

    fase = _FaseApi.tokenVencido;
    await tester.ensureVisible(find.text('Historico'));
    await tester.tap(find.text('Historico'));
    await _pumpApp(tester);

    expect(find.text('Entrar na conta'), findsOneWidget);
    expect(find.text(sessionExpiredMessage), findsOneWidget);
    expect(await tokenStore.hasAccessToken(), isFalse);
    expect(appNavigatorKey.currentState!.canPop(), isFalse);
  });
}

enum _FaseApi { tokenVencido, sessaoNova }

const _userBody = {
  'user_id': 'user_1',
  'email': 'ana@example.com',
  'display_name': 'Ana',
  'terms_version': '1.0',
  'privacy_version': '1.0',
};

const _statusBody = {'has_cv': true, 'has_embeddings': true};

const _loginBody = {'access_token': 'jwt-novo', 'user': _userBody};

Future<void> _pumpApp(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<void> _prepareSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _seedOpenSession(
  MemoryTokenStore store, {
  bool biometria = false,
}) async {
  final box = Hive.box<String>('app_session');
  await box.put('user_id', 'user_1');
  await box.put('email', 'ana@example.com');
  await box.put('display_name', 'Ana');
  await box.put('has_cv', 'true');
  if (biometria) {
    await BiometricPreferenceStore(box).enableForUser('user_1');
  }
  await store.writeAccessToken('jwt-velho');
}

Widget _app(MemoryTokenStore store, {List<Override> overrides = const []}) {
  return testProviderScope(
    tokenStore: store,
    overrides: overrides,
    child: const MyApp(),
  );
}

Dio _dioThatFails(
  MemoryTokenStore store, {
  int statusCode = 401,
  String detail = 'Token expirado',
}) {
  bindApiHttpClientAdapter(
    _ScriptedAdapter((options) async => _json(statusCode, {'detail': detail})),
  );
  return createApiDio(tokenStore: store);
}

Future<void> _ignoreDio(Future<Response<dynamic>> request) async {
  try {
    await request;
  } on DioException {
    return;
  }
}

ResponseBody _json(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _respond(options);
  }
}

class _BiometriaAprovada implements BiometricAuthService {
  @override
  Future<bool> authenticate({required String reason}) async => true;

  @override
  Future<bool> canUseBiometrics() async => true;
}
