import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agente_emprego/data/consent_outdated.dart';
import 'package:agente_emprego/data/history_errors.dart';
import 'package:agente_emprego/data/legal_versions.dart';
import 'package:agente_emprego/data/models/gap_history_item.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/repositories/chat_repository_impl.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/history_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('GapHistoryItem parser', () {
    test('mapeia items da API e ignora linhas invalidas', () {
      final items = GapHistoryItem.listFromResponse({
        'items': [
          {
            'id': 42,
            'job_title': 'Desenvolvedor Flutter',
            'company_name': 'Acme',
            'job_summary': 'Vaga para app mobile',
            'match_score': 81,
            'strengths': ['Dart', 'Riverpod'],
            'critical_gaps': ['Kubernetes'],
            'created_at': '2026-09-01T15:04:00Z',
          },
          {'job_title': 'sem id'},
          'nao-e-mapa',
          {
            'insight_id': 'mongo-1',
            'job_title': 'QA',
            'match_score': '70',
            'created_at': '2026-08-20T10:00:00.000Z',
          },
        ],
        'limit': 20,
        'offset': 0,
      });

      expect(items, hasLength(2));
      expect(items.first.id, '42');
      expect(items.first.jobTitle, 'Desenvolvedor Flutter');
      expect(items.first.matchScore, 81);
      expect(items.first.strengths, ['Dart', 'Riverpod']);
      expect(items.first.criticalGaps, ['Kubernetes']);
      expect(items.first.createdAt, DateTime.parse('2026-09-01T15:04:00Z'));
      expect(items.last.id, 'mongo-1');
      expect(items.last.matchScore, 70);
    });

    test('resposta vazia ou sem items vira lista vazia', () {
      expect(GapHistoryItem.listFromResponse(null), isEmpty);
      expect(GapHistoryItem.listFromResponse({'limit': 20}), isEmpty);
      expect(GapHistoryItem.listFromResponse({'items': []}), isEmpty);
    });

    test('monta texto de card sem vazar campos nulos', () {
      const item = GapHistoryItem(
        id: '1',
        jobTitle: 'Flutter',
        companyName: 'Acme',
        jobSummary: 'Resumo da vaga',
        matchScore: 64,
        strengths: ['Dart'],
        criticalGaps: ['AWS'],
        generationBlocked: true,
        blockedReason: 'low_match_score',
      );

      expect(item.displayText, contains('Flutter'));
      expect(item.displayText, contains('Empresa: Acme'));
      expect(item.displayText, contains('Aderencia: 64/100'));
      expect(item.displayText, contains('PDF nao gerado: low_match_score'));
      expect(item.displayText, contains('Pontos fortes: Dart'));
      expect(item.displayText, contains('Lacunas criticas: AWS'));
      expect(item.toChatMessage().isUser, isFalse);
    });
  });

  group('ChatRepositoryImpl.fetchGapHistory', () {
    late Box<MessageModel> chatBox;

    setUpAll(() async {
      final tempDir = await Directory.systemTemp.createTemp('gap_history_repo');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(MessageModelAdapter());
      }
      chatBox = await Hive.openBox<MessageModel>('gap_history_repo');
    });

    tearDownAll(() async {
      await chatBox.close();
    });

    test('GET /users/me/gap-history com Bearer e sem JWT no erro', () async {
      final store = MemoryTokenStore(accessToken: 'jwt-history-secret');
      late RequestOptions captured;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _JsonAdapter(
        onFetch: (options) => captured = options,
        statusCode: 200,
        body: {
          'items': [
            {
              'id': 'run-1',
              'job_title': 'Analista de Dados',
              'match_score': 55,
              'created_at': '2026-09-02T08:00:00Z',
            },
          ],
        },
      );

      final items = await ChatRepositoryImpl(
        chatBox,
        tokenStore: store,
        dio: dio,
      ).fetchGapHistory();

      expect(captured.method, 'GET');
      expect(captured.path, ChatRepositoryImpl.gapHistoryPath);
      expect(captured.queryParameters['limit'], 50);
      expect(captured.headers['Authorization'], 'Bearer jwt-history-secret');
      expect(captured.headers['X-User-Id'], isNull);
      expect(captured.headers['x-user-id'], isNull);
      expect(items, hasLength(1));
      expect(items.single.jobTitle, 'Analista de Dados');
    });

    test('nao envia X-User-Id mesmo com userId de outro usuario no client', () async {
      final store = MemoryTokenStore(accessToken: 'jwt-owner');
      late RequestOptions captured;
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://example.test',
          headers: {'X-User-Id': 'victim-user'},
        ),
      );
      dio.httpClientAdapter = _JsonAdapter(
        onFetch: (options) => captured = options,
        body: {'items': []},
      );

      await ChatRepositoryImpl(
        chatBox,
        tokenStore: store,
        userId: 'victim-user',
        dio: dio,
      ).fetchGapHistory();

      expect(captured.headers['Authorization'], 'Bearer jwt-owner');
      expect(captured.headers['X-User-Id'], isNull);
      expect(captured.headers['x-user-id'], isNull);
      expect(captured.queryParameters.containsKey('user_id'), isFalse);
    });

    test('sem token nao chama a API', () async {
      var called = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _JsonAdapter(
        onFetch: (_) => called = true,
        body: {'items': []},
      );

      expect(
        () => ChatRepositoryImpl(
          chatBox,
          tokenStore: MemoryTokenStore(),
          dio: dio,
        ).fetchGapHistory(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Entre na sua conta para ver o historico'),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('sessao travada nao envia Authorization', () async {
      final store = MemoryTokenStore(accessToken: 'jwt-must-stay-in-vault');
      store.suppressReads();
      var called = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _JsonAdapter(
        onFetch: (_) => called = true,
        body: {'items': []},
      );

      expect(
        () => ChatRepositoryImpl(
          chatBox,
          tokenStore: store,
          dio: dio,
        ).fetchGapHistory(),
        throwsA(isA<Exception>()),
      );
      expect(called, isFalse);
      expect(await store.hasAccessToken(), isTrue);
    });

    test('erro HTTP vira mensagem sem o token', () async {
      final store = MemoryTokenStore(accessToken: 'jwt-should-not-leak');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = _JsonAdapter(
        onFetch: (_) {},
        statusCode: 401,
        body: {'detail': 'Nao autenticado'},
      );

      try {
        await ChatRepositoryImpl(
          chatBox,
          tokenStore: store,
          dio: dio,
        ).fetchGapHistory();
        fail('esperava Exception');
      } on Exception catch (error) {
        expect(error.toString(), contains(historySessionExpiredMessage));
        expect(error.toString(), isNot(contains('jwt-should-not-leak')));
        expect(error.toString(), isNot(contains('/users/me/gap-history')));
        expect(error.toString(), isNot(contains('Nao autenticado')));
        expect(historyErrorLeaksInternals(error.toString()), isFalse);
      }
    });

    test('erro 500 nao vaza path interno nem URL da API', () async {
      final store = MemoryTokenStore(accessToken: 'jwt-should-not-leak');
      final dio = Dio(BaseOptions(baseUrl: 'https://meu-agente-de-emprego.onrender.com'));
      dio.httpClientAdapter = _JsonAdapter(
        onFetch: (_) {},
        statusCode: 500,
        body: {
          'detail':
              'File "/app/main.py", line 12, in read_gap_history GET /users/me/gap-history',
        },
      );

      try {
        await ChatRepositoryImpl(
          chatBox,
          tokenStore: store,
          dio: dio,
        ).fetchGapHistory();
        fail('esperava Exception');
      } on Exception catch (error) {
        expect(error.toString(), contains(historyLoadFailedMessage));
        expect(historyErrorLeaksInternals(error.toString()), isFalse);
        expect(error.toString(), isNot(contains('onrender.com')));
        expect(error.toString(), isNot(contains('jwt-should-not-leak')));
      }
    });
  });

  group('HistoryNotifier', () {
    test('usa a API quando ela devolve analises', () async {
      final notifier = HistoryNotifier(
        fetchRemote: () async => [
          GapHistoryItem(
            id: 'api-1',
            jobTitle: 'Dev Flutter',
            matchScore: 90,
            createdAt: DateTime(2026, 9, 1, 12),
          ),
        ],
      );

      await notifier.refresh();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.fromRemote, isTrue);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.items, hasLength(1));
      expect(notifier.state.items.single.id, 'api-1');
      expect(notifier.state.items.single.text, contains('Dev Flutter'));
    });

    test('API vazia mostra vazio e nao mistura Hive de outro usuario', () async {
      final notifier = HistoryNotifier(
        fetchRemote: () async => const [],
      );

      await notifier.refresh();

      expect(notifier.state.fromRemote, isTrue);
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.errorMessage, isNull);
    });

    test('erro da API mostra mensagem segura sem fallback local', () async {
      var consentCalled = false;
      final notifier = HistoryNotifier(
        fetchRemote: () async {
          throw const ConsentOutdatedException(
            doc: LegalDoc.terms,
            code: ConsentOutdatedException.termsCode,
            message: 'Termos desatualizados',
          );
        },
        onConsentOutdated: (_) => consentCalled = true,
      );

      await notifier.refresh();

      expect(consentCalled, isTrue);
      expect(notifier.state.errorMessage, 'Termos desatualizados');
      expect(notifier.state.items, isEmpty);
    });

    test('sanitiza traceback e path no estado de erro', () async {
      final notifier = HistoryNotifier(
        fetchRemote: () async {
          throw Exception(
            'HTTP 500: File "/app/main.py" GET /users/me/gap-history '
            'https://meu-agente-de-emprego.onrender.com Bearer jwt-abc',
          );
        },
      );

      await notifier.refresh();

      expect(notifier.state.errorMessage, historyLoadFailedMessage);
      expect(historyErrorLeaksInternals(notifier.state.errorMessage!), isFalse);
      expect(notifier.state.items, isEmpty);
    });
  });

  group('safeHistoryErrorMessage', () {
    test('nao devolve URL, path ou token', () {
      final error = DioException(
        requestOptions: RequestOptions(
          path: '/users/me/gap-history',
          headers: {'Authorization': 'Bearer jwt-secret'},
        ),
        type: DioExceptionType.connectionError,
      );

      final message = safeHistoryErrorMessage(error);
      expect(message, historyLoadFailedMessage);
      expect(historyErrorLeaksInternals(message), isFalse);
    });
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter({
    required this.onFetch,
    this.body = const {},
    this.statusCode = 200,
  });

  final void Function(RequestOptions options) onFetch;
  final Object body;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
