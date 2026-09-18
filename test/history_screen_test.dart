import 'dart:io';

import 'package:agente_emprego/data/models/gap_history_item.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/token_store.dart';
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

  testWidgets('mostra erro e retry quando a API falha sem fallback', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        overrides: [
          gapHistoryFetcherProvider.overrideWithValue(() async {
            calls += 1;
            throw Exception('Falha ao carregar o historico');
          }),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nao foi possivel carregar o historico.'), findsOneWidget);
    expect(find.text('Falha ao carregar o historico'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(calls, 2);
  });
}
