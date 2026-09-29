import 'dart:io';

import 'package:agente_emprego/data/cover_letter_gate.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/repositories/auth_repository_impl.dart';
import 'package:agente_emprego/data/repositories/cover_letter_repository_impl.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/chat_provider.dart';
import 'package:agente_emprego/presentation/providers/cover_letter_provider.dart';
import 'package:agente_emprego/presentation/screens/cover_letter_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/session_test_harness.dart';

void main() {
  late MemoryTokenStore tokenStore;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('cover_letter_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    if (!Hive.isBoxOpen('chat_history')) {
      await Hive.openBox<MessageModel>('chat_history');
    }
    if (!Hive.isBoxOpen('app_session')) {
      await Hive.openBox<String>('app_session');
    }
  });

  setUp(() {
    tokenStore = bindTestTokenStore(accessToken: 'token');
  });

  testWidgets('C1 sem embeddings deixa Gerar indisponivel e pede o CV', (
    WidgetTester tester,
  ) async {
    final script = _LetterScript(allowPost: false);
    await _pumpCoverLetter(
      tester,
      tokenStore: tokenStore,
      statuses: const [
        UserStatusData(hasCv: true, hasEmbeddings: false),
      ],
      script: script,
    );

    expect(find.text(CoverLetterGate.updateCvMessage), findsWidgets);
    expect(find.text('Enviar ou atualizar curriculo'), findsOneWidget);
    expect(_generateButton(tester).onPressed, isNull);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(script.posts, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('C2 com embeddings gera a carta no fluxo atual', (
    WidgetTester tester,
  ) async {
    final script = _LetterScript(
      statusCode: 200,
      data: {
        'texto_resposta': 'Carta para a Nexa',
        'pdf_url': 'https://example.test/carta.pdf',
      },
    );
    await _pumpCoverLetter(
      tester,
      tokenStore: tokenStore,
      statuses: const [
        UserStatusData(hasCv: true, hasEmbeddings: true),
        UserStatusData(hasCv: true, hasEmbeddings: true),
      ],
      script: script,
    );

    expect(find.text(CoverLetterGate.updateCvMessage), findsNothing);
    expect(_generateButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), 'Nexa Talent');
    await tester.tap(find.widgetWithText(FilledButton, 'Gerar carta'));
    await _pumpUntil(tester, find.text('Carta para a Nexa'));

    expect(script.posts, 1);
    expect(script.lastBody, {'empresa': 'Nexa Talent'});
    expect(find.text('Carta para a Nexa'), findsOneWidget);
    expect(find.text('Gerando'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_generateButton(tester).onPressed, isNotNull);
  });

  testWidgets('C3 falha de status nao gera e oferece nova tentativa', (
    WidgetTester tester,
  ) async {
    final script = _LetterScript(allowPost: false);
    await _pumpCoverLetter(
      tester,
      tokenStore: tokenStore,
      statuses: const [
        UserStatusData(hasCv: true, hasEmbeddings: false),
      ],
      statusError: Exception('Falha ao autenticar com a API'),
      script: script,
    );

    expect(
      find.textContaining(CoverLetterGate.statusErrorMessage),
      findsWidgets,
    );
    expect(find.textContaining('Falha ao autenticar com a API'), findsWidgets);
    expect(_generateButton(tester).onPressed, isNull);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(script.posts, 0);

    await tester.tap(find.text('Tentar novamente'));
    await _pumpUntil(tester, find.text(CoverLetterGate.updateCvMessage));

    expect(find.text(CoverLetterGate.updateCvMessage), findsWidgets);
    expect(_generateButton(tester).onPressed, isNull);
    expect(script.posts, 0);
  });

  testWidgets('C3 status que cai antes de gerar nao dispara a carta', (
    WidgetTester tester,
  ) async {
    final script = _LetterScript(allowPost: false);
    await _pumpCoverLetter(
      tester,
      tokenStore: tokenStore,
      statuses: const [
        UserStatusData(hasCv: true, hasEmbeddings: true),
        UserStatusData(hasCv: true, hasEmbeddings: false),
      ],
      script: script,
    );

    expect(_generateButton(tester).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField), 'Nexa Talent');
    await tester.tap(find.widgetWithText(FilledButton, 'Gerar carta'));
    await _pumpUntil(tester, find.text(CoverLetterGate.updateCvMessage));

    expect(script.posts, 0);
    expect(find.text('Carta para a Nexa'), findsNothing);
    expect(_generateButton(tester).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('C4 402 mostra detail da cota e encerra o spinner', (
    WidgetTester tester,
  ) async {
    final script = _LetterScript(
      statusCode: 402,
      data: {
        'detail': {
          'code': 'SUBSCRIPTION_REQUIRED',
          'message': 'Cota gratuita do mes esgotada.',
        },
      },
    );
    await _pumpCoverLetter(
      tester,
      tokenStore: tokenStore,
      statuses: const [
        UserStatusData(hasCv: true, hasEmbeddings: true),
        UserStatusData(hasCv: true, hasEmbeddings: true),
      ],
      script: script,
    );

    await tester.enterText(find.byType(TextField), 'Nexa Talent');
    await tester.tap(find.widgetWithText(FilledButton, 'Gerar carta'));
    await _pumpUntil(
      tester,
      find.textContaining('Cota gratuita do mes esgotada.'),
    );

    expect(script.posts, 1);
    expect(
      find.textContaining('HTTP 402: Cota gratuita do mes esgotada.'),
      findsOneWidget,
    );
    expect(find.textContaining('desconhecido'), findsNothing);
    expect(find.textContaining('Erro inesperado'), findsNothing);
    expect(find.text('Gerando'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Gerar carta'), findsOneWidget);
  });

  testWidgets('C5 422 mostra detail de parse invalido e encerra o spinner', (
    WidgetTester tester,
  ) async {
    final script = _LetterScript(
      statusCode: 422,
      data: {
        'detail': 'Nao foi possivel validar os dados enviados.',
      },
    );
    await _pumpCoverLetter(
      tester,
      tokenStore: tokenStore,
      statuses: const [
        UserStatusData(hasCv: true, hasEmbeddings: true),
        UserStatusData(hasCv: true, hasEmbeddings: true),
      ],
      script: script,
    );

    await tester.enterText(find.byType(TextField), 'Nexa Talent');
    await tester.tap(find.widgetWithText(FilledButton, 'Gerar carta'));
    await _pumpUntil(
      tester,
      find.textContaining('Nao foi possivel validar os dados enviados.'),
    );

    expect(script.posts, 1);
    expect(
      find.textContaining(
        'HTTP 422: Nao foi possivel validar os dados enviados.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('desconhecido'), findsNothing);
    expect(find.text('Gerando'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

FilledButton _generateButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Gerar carta'),
  );
}

Future<void> _pumpCoverLetter(
  WidgetTester tester, {
  required MemoryTokenStore tokenStore,
  required List<UserStatusData> statuses,
  required _LetterScript script,
  Exception? statusError,
}) async {
  var index = 0;
  await tester.pumpWidget(
    testProviderScope(
      tokenStore: tokenStore,
      overrides: [
        userStatusFetcherProvider.overrideWith((ref) {
          return () async {
            if (statusError != null && index == 0) {
              index++;
              throw statusError;
            }
            if (index >= statuses.length) {
              return statuses.last;
            }
            return statuses[index++];
          };
        }),
        generateCoverLetterProvider.overrideWith(
          (ref) => _generator(tokenStore, script.build()),
        ),
      ],
      child: const MaterialApp(home: CoverLetterScreen()),
    ),
  );
  await tester.pump();
  await _pumpUntil(tester, find.text('Gerar carta'));
  await tester.pump(const Duration(milliseconds: 300));
}

GenerateCoverLetter _generator(TokenStore tokenStore, Dio dio) {
  final repository = CoverLetterRepositoryImpl(
    dio: dio,
    tokenStore: tokenStore,
  );
  return ({required String companyName, required String authToken}) {
    return repository.generateCoverLetter(
      companyName: companyName,
      authToken: authToken,
    );
  };
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _LetterScript {
  _LetterScript({
    this.allowPost = true,
    this.statusCode = 200,
    this.data = const <String, dynamic>{},
  });

  final bool allowPost;
  final int statusCode;
  final dynamic data;
  int posts = 0;
  dynamic lastBody;

  Dio build() {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!allowPost) {
            fail('POST ${options.path} nao deveria acontecer');
          }
          posts++;
          lastBody = options.data;
          if (statusCode >= 200 && statusCode < 300) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: statusCode,
                data: data,
              ),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: statusCode,
                data: data,
              ),
            ),
          );
        },
      ),
    );
    return dio;
  }
}
