import 'dart:io';

import 'package:agente_emprego/data/analyze_gate.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/repositories/auth_repository_impl.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/session_provider.dart';
import 'package:agente_emprego/presentation/screens/chat_screen.dart';
import 'package:agente_emprego/presentation/screens/home_screen.dart';
import 'package:agente_emprego/presentation/screens/user_registration_screen.dart';
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
    await SessionNotifier(sessionBox, tokenStore).saveSession(
      authToken: 'token',
      userId: 'user_1',
      email: 'user@example.com',
      displayName: 'Usuario Teste',
      hasCv: true,
    );
  });

  testWidgets('Home forca upload de CV quando nao ha embeddings', (
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(UserRegistrationScreen), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.textContaining('curriculo'), findsWidgets);
    expect(find.text(AnalyzeGate.missingEmbeddingsMessage), findsWidgets);

    await tester.pump(const Duration(seconds: 5));
  });
}
