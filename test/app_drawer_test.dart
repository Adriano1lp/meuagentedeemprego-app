import 'dart:io';

import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/session_provider.dart';
import 'package:agente_emprego/presentation/screens/chat_screen.dart';
import 'package:agente_emprego/presentation/screens/home_screen.dart';
import 'package:agente_emprego/presentation/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/session_test_harness.dart';

void main() {
  late MemoryTokenStore tokenStore;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('drawer_test');
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

  testWidgets('menu nao mostra API atual e mostra analise de vaga', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        child: const MaterialApp(
          home: AppDrawer(),
        ),
      ),
    );

    expect(find.text('API atual'), findsNothing);
    expect(find.text('http://127.0.0.1:8000'), findsNothing);
    expect(find.text('Analise de vaga'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('Home no drawer abre HomeScreen e nao ChatScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Analise da Vaga'), findsNothing);
  });
}
