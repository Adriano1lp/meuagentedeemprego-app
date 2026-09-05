import 'dart:io';

import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/session_test_harness.dart';

void main() {
  late MemoryTokenStore tokenStore;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('agente_emprego_test');
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
    await Hive.box<String>('app_session').clear();
  });

  tearDownAll(() async {
    await Hive.box<MessageModel>('chat_history').close();
    await Hive.box<String>('app_session').close();
  });

  testWidgets('renderiza a tela inicial de autenticacao', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testProviderScope(
        tokenStore: tokenStore,
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrar na conta'), findsOneWidget);
    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Criar conta'), findsWidgets);
  });
}
