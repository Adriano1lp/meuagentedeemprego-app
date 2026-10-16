import 'dart:io';

import 'package:agente_emprego/data/api_errors.dart';
import 'package:agente_emprego/data/history_errors.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/repositories/auth_repository_impl.dart';
import 'package:agente_emprego/data/repositories/chat_repository_impl.dart';
import 'package:agente_emprego/data/repositories/user_repository_impl.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/chat_provider.dart';
import 'package:agente_emprego/presentation/screens/chat_screen.dart';
import 'package:agente_emprego/presentation/utils/authenticated_pdf_opener.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/session_test_harness.dart';

const _steeringBody = {
  'detail': {
    'code': 'SUBSCRIPTION_REQUIRED',
    'message':
        'Cota gratuita esgotada. Assine em https://example.test/checkout por R\$ 29.',
    'checkout_url': 'https://example.test/checkout',
    'plan': 'free',
    'used': 5,
    'limit': 5,
  },
};

void main() {
  late MemoryTokenStore tokenStore;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('quota_limit_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    if (!Hive.isBoxOpen('chat_history')) {
      await Hive.openBox<MessageModel>('chat_history');
    }
  });

  setUp(() {
    tokenStore = MemoryTokenStore(accessToken: 'token');
    bindActiveTokenStore(tokenStore);
  });

  test('a frase de cota nao tem preco, link nem convite de compra', () {
    expect(monthlyQuotaLimitMessage, 'Você atingiu o limite do seu plano este mês');
    expect(_steersToPayment(monthlyQuotaLimitMessage), isFalse);
  });

  test('POST /processar 402 vira a frase neutra', () async {
    final repository = ChatRepositoryImpl(
      Hive.box<MessageModel>('chat_history'),
      tokenStore: tokenStore,
      dio: _dioThatRejects(402, _steeringBody),
    );

    await _expectNeutral(() => repository.sendMessage(_jobDescription));
  });

  test('upload e rebuild 402 viram a frase neutra', () async {
    final upload = UserRepositoryImpl(
      dio: _dioThatRejects(402, _steeringBody),
      tokenStore: tokenStore,
    );
    await _expectNeutral(
      () => upload.uploadCv(
        authToken: 'token',
        fileName: 'cv.pdf',
        fileBytes: const [1, 2, 3],
      ),
    );

    final rebuild = UserRepositoryImpl(
      dio: _dioThatRejects(402, _steeringBody),
      tokenStore: tokenStore,
    );
    await _expectNeutral(() => rebuild.rebuildEmbeddings(authToken: 'token'));
  });

  test('login 402 vira a frase neutra', () async {
    final repository = AuthRepositoryImpl(
      dio: _dioThatRejects(402, _steeringBody),
      tokenStore: tokenStore,
    );

    await _expectNeutral(
      () => repository.login(email: 'ana@example.test', password: 'segredo'),
    );
  });

  test('historico 402 usa a frase neutra e nao o corpo da API', () async {
    final repository = ChatRepositoryImpl(
      Hive.box<MessageModel>('chat_history'),
      tokenStore: tokenStore,
      dio: _dioThatRejects(402, _steeringBody),
    );

    await _expectNeutral(() => repository.fetchGapHistory());
    expect(
      safeHistoryErrorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/users/me/gap-history'),
          response: Response(
            requestOptions: RequestOptions(path: '/users/me/gap-history'),
            statusCode: 402,
            data: _steeringBody,
          ),
        ),
      ),
      monthlyQuotaLimitMessage,
    );
  });

  test('download de PDF 402 usa a frase neutra e outros detail seguem crus', () {
    final quota = authenticatedPdfDownloadMessage(
      DioException(
        requestOptions: RequestOptions(path: '/users/me/files/carta.pdf'),
        response: Response(
          requestOptions: RequestOptions(path: '/users/me/files/carta.pdf'),
          statusCode: 402,
          data: _steeringBody,
        ),
      ),
    );
    expect(quota, monthlyQuotaLimitMessage);
    expect(_steersToPayment(quota), isFalse);

    const plain = 'Arquivo indisponivel.';
    expect(
      authenticatedPdfDownloadMessage(
        DioException(
          requestOptions: RequestOptions(path: '/users/me/files/carta.pdf'),
          response: Response(
            requestOptions: RequestOptions(path: '/users/me/files/carta.pdf'),
            statusCode: 404,
            data: {'detail': plain},
          ),
        ),
      ),
      plain,
    );
  });

  test('lib nao tem botao, URL nem termo de pagamento', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'rodar o teste na raiz do pacote');

    final steering = RegExp(
      r'\b(checkout|stripe|assinar|assinatura|upgrade|pagamento|pricing|billing|subscribe|subscription)\b',
      caseSensitive: false,
    );
    final urlPattern = RegExp(r'''https?://[^'"\s)]+''');
    final hits = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      final relative = entity.path;
      for (final match in steering.allMatches(source)) {
        hits.add('$relative: ${match.group(0)}');
      }
      for (final match in urlPattern.allMatches(source)) {
        final url = match.group(0)!;
        if (_urlLooksLikePayment(url)) {
          hits.add('$relative: $url');
        }
      }
    }

    expect(hits, isEmpty);

    final launcherFile = File('lib/presentation/screens/job_search_screen.dart');
    final launcherSource = launcherFile.readAsStringSync();
    expect(launcherSource, contains('launchUrl'));
    final links = RegExp(
      r'''https?://[^'"\s)]+''',
    ).allMatches(launcherSource).map((match) => match.group(0)!);
    expect(links, isNotEmpty);
    for (final link in links) {
      expect(Uri.parse(link).host, 'www.linkedin.com');
      expect(link, isNot(contains('checkout')));
    }
  });

  testWidgets('analise da vaga mostra a frase neutra no 402', (tester) async {
    final dio = _dioThatRejects(402, _steeringBody);
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        overrides: [
          chatProvider.overrideWith((ref) {
            return ChatNotifier(
              ChatRepositoryImpl(
                Hive.box<MessageModel>('chat_history'),
                tokenStore: tokenStore,
                dio: dio,
              ),
              fetchUserStatus: () async => const UserStatusData(
                hasCv: true,
                hasEmbeddings: true,
              ),
            );
          }),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final buttonFinder = find.widgetWithText(FilledButton, 'Analisar vaga');
    expect(buttonFinder, findsOneWidget);
    await tester.enterText(find.byType(TextField), _jobDescription);
    await tester.ensureVisible(buttonFinder);
    // Hive writes a real file. Widget tests use fake async, so the send
    // has to run on the real event queue or saveToDisk never finishes.
    await tester.runAsync(() async {
      tester.widget<FilledButton>(buttonFinder).onPressed!.call();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await _pumpUntil(tester, find.text(monthlyQuotaLimitMessage));

    expect(find.text(monthlyQuotaLimitMessage), findsOneWidget);
    expect(find.textContaining('HTTP 402'), findsNothing);
    expect(find.textContaining('checkout'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('Assine'), findsNothing);
    expect(find.textContaining('Cota gratuita'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Assinar'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Upgrade'), findsNothing);
    expect(find.text('Analisando'), findsNothing);
  });
}

const _jobDescription = '''
Vaga para Analista de Dados Senior.
Responsabilidades: construir dashboards, analisar indicadores e apoiar decisoes de negocio.
Requisitos: experiencia com SQL, Power BI, Python e comunicacao com areas de produto.
Contratacao PJ hibrido com beneficios e bonus por performance.
''';

Future<void> _expectNeutral(Future<Object?> Function() action) async {
  try {
    await action();
    fail('esperava Exception');
  } on Exception catch (error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    expect(text, monthlyQuotaLimitMessage);
    expect(_steersToPayment(text), isFalse);
    expect(text, isNot(contains('HTTP 402')));
    expect(text, isNot(contains('checkout')));
    expect(text, isNot(contains('Assine')));
    expect(text, isNot(contains('Cota gratuita')));
  }
}

Dio _dioThatRejects(int statusCode, dynamic data) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
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

bool _steersToPayment(String text) {
  final lower = text.toLowerCase();
  const needles = [
    'http://',
    'https://',
    'www.',
    'r\$',
    'preco',
    'preço',
    'assine',
    'assinar',
    'stripe',
    'checkout',
    'upgrade',
    'site',
    'web',
    'pagamento',
    'subscription',
    'comprar',
    'gratuita',
    'gratis',
  ];
  return needles.any(lower.contains);
}

bool _urlLooksLikePayment(String url) {
  final lower = url.toLowerCase();
  const needles = [
    'checkout',
    'stripe',
    'billing',
    'pricing',
    'assinar',
    'subscribe',
    'pay.',
  ];
  return needles.any(lower.contains);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}
