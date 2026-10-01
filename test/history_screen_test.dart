import 'dart:io';

import 'package:agente_emprego/data/history_errors.dart';
import 'package:agente_emprego/data/models/gap_history_item.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/repositories/cv_file_repository.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/cv_file_provider.dart';
import 'package:agente_emprego/presentation/providers/history_provider.dart';
import 'package:agente_emprego/presentation/providers/session_provider.dart';
import 'package:agente_emprego/presentation/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/session_test_harness.dart';

void main() {
  late MemoryTokenStore tokenStore;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'history_screen_test',
    );
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

  setUp(() async {
    tokenStore = bindTestTokenStore();
    await Hive.box<MessageModel>('chat_history').clear();
    final sessionBox = Hive.box<String>('app_session');
    await sessionBox.clear();
    await SessionNotifier(sessionBox, tokenStore).saveSession(
      authToken: 'token',
      userId: 'user_1',
      email: 'user@example.com',
      displayName: 'Usuario Teste',
      hasCv: true,
    );
  });

  tearDownAll(() async {
    await Hive.box<MessageModel>('chat_history').close();
    await Hive.box<String>('app_session').close();
  });

  testWidgets('mostra analises retornadas pela API', (tester) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        overrides: [
          gapHistoryFetcherProvider.overrideWithValue(
            () async => [
              GapHistoryItem(
                id: 'api-1',
                jobTitle: 'Desenvolvedor Flutter',
                companyName: 'Acme',
                jobSummary: 'Vaga remota com Dart',
                matchScore: 88,
                createdAt: DateTime(2026, 9, 1, 14, 5),
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Historico'), findsOneWidget);
    expect(find.textContaining('Desenvolvedor Flutter'), findsWidgets);
    expect(find.textContaining('Aderencia: 88/100'), findsWidgets);
    expect(find.text('Nenhum retorno salvo ainda.'), findsNothing);
  });

  testWidgets('mostra vazio claro quando a API nao tem analises', (
    tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        overrides: [
          gapHistoryFetcherProvider.overrideWithValue(() async => const []),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nenhum retorno salvo ainda.'), findsOneWidget);
  });

  testWidgets('mostra erro seguro sem path interno quando a API falha', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        overrides: [
          gapHistoryFetcherProvider.overrideWithValue(() async {
            calls += 1;
            throw Exception(
              'HTTP 500: File "/app/main.py" GET /users/me/gap-history '
              'https://meu-agente-de-emprego.onrender.com Bearer jwt-abc',
            );
          }),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nao foi possivel carregar o historico.'), findsOneWidget);
    expect(find.text(historyLoadFailedMessage), findsOneWidget);
    expect(find.textContaining('/users/me/gap-history'), findsNothing);
    expect(find.textContaining('onrender.com'), findsNothing);
    expect(find.textContaining('Bearer'), findsNothing);
    expect(find.textContaining('jwt-abc'), findsNothing);
    expect(find.textContaining('main.py'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(calls, 2);
  });

  testWidgets('C1 com cv_file_name mostra Baixar CV e baixa esse arquivo', (
    tester,
  ) async {
    final downloaded = <String>[];
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        overrides: [
          gapHistoryFetcherProvider.overrideWithValue(
            () async => [
              GapHistoryItem(
                id: 'com-cv',
                jobTitle: 'Analista',
                matchScore: 70,
                cvFileName: 'cv_otimizado.pdf',
              ),
            ],
          ),
          cvFileDownloadProvider.overrideWithValue((fileName) async {
            downloaded.add(fileName);
          }),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Baixar CV'), findsOneWidget);
    expect(find.text('Abrir PDF'), findsNothing);

    await tester.tap(find.text('Baixar CV'));
    await tester.pumpAndSettle();

    expect(downloaded, ['cv_otimizado.pdf']);
  });

  testWidgets('C2 sem cv_file_name nao mostra Baixar CV', (tester) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        overrides: [
          gapHistoryFetcherProvider.overrideWithValue(
            () async => [
              GapHistoryItem(
                id: 'sem-cv',
                jobTitle: 'Designer',
                matchScore: 40,
                cvFileName: null,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Designer'), findsWidgets);
    expect(find.text('Baixar CV'), findsNothing);
    expect(find.text('Abrir PDF'), findsNothing);
  });

  testWidgets('C4 erro de download mostra so a mensagem fixa', (tester) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        overrides: [
          gapHistoryFetcherProvider.overrideWithValue(
            () async => [
              const GapHistoryItem(
                id: 'falha',
                jobTitle: 'QA',
                cvFileName: 'cv_qa.pdf',
              ),
            ],
          ),
          cvFileDownloadProvider.overrideWithValue((fileName) async {
            throw Exception(
              'Bearer jwt-secret <html> /users/me/files/cv_qa.pdf',
            );
          }),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Baixar CV'));
    await tester.pumpAndSettle();

    expect(find.text(cvDownloadFailedMessage), findsOneWidget);
    expect(find.textContaining('jwt-secret'), findsNothing);
    expect(find.textContaining('Bearer'), findsNothing);
    expect(find.textContaining('<html>'), findsNothing);
    expect(find.textContaining('/users/me/files'), findsNothing);
  });
}
