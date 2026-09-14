import 'dart:io';

import 'package:agente_emprego/data/analyze_gate.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/repositories/auth_repository_impl.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/session_provider.dart';
import 'package:agente_emprego/presentation/screens/chat_screen.dart';
import 'package:agente_emprego/presentation/screens/home_screen.dart';
import 'package:agente_emprego/presentation/screens/user_registration_screen.dart';
import 'package:agente_emprego/presentation/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/session_test_harness.dart';

void main() {
  late MemoryTokenStore tokenStore;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('analyze_nav_test');
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
    tokenStore = bindTestTokenStore(accessToken: 'token');
    await Hive.box<MessageModel>('chat_history').clear();
    final sessionBox = Hive.box<String>('app_session');
    await sessionBox.clear();
    await SessionNotifierForTest.save(
      tokenStore,
      hasCv: true,
    );
  });

  tearDownAll(() async {
    await Hive.box<MessageModel>('chat_history').close();
    await Hive.box<String>('app_session').close();
  });

  testWidgets('Home força upload de CV quando nao ha embeddings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        userStatus: const UserStatusData(hasCv: true, hasEmbeddings: false),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.tap(find.text('Analise de vaga'));
    await tester.pumpAndSettle();

    expect(find.byType(UserRegistrationScreen), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.text(AnalyzeGate.missingEmbeddingsMessage), findsWidgets);
  });

  testWidgets('Home abre Analisar quando has_embeddings e true', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.tap(find.text('Analise de vaga'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Analise da Vaga'), findsOneWidget);
  });

  testWidgets('Analisar vaga fica desabilitado sem embeddings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        userStatus: const UserStatusData(hasCv: true, hasEmbeddings: false),
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AnalyzeGate.missingEmbeddingsMessage), findsWidgets);
    expect(find.text('Enviar curriculo'), findsOneWidget);

    final analyzeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Analisar vaga'),
    );
    expect(analyzeButton.onPressed, isNull);
  });

  testWidgets('drawer de Analise tambem força CV sem embeddings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        userStatus: const UserStatusData(hasCv: true, hasEmbeddings: false),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AppDrawer),
      matching: find.text('Analise de vaga'),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(UserRegistrationScreen), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
  });
}

class SessionNotifierForTest {
  static Future<void> save(TokenStore tokenStore, {required bool hasCv}) async {
    final sessionBox = Hive.box<String>('app_session');
    await SessionNotifier(sessionBox, tokenStore).saveSession(
      authToken: 'token',
      userId: 'user_1',
      email: 'user@example.com',
      displayName: 'Usuario Teste',
      hasCv: hasCv,
    );
  }
}
