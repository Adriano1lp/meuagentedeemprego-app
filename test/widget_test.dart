import 'dart:io';

import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('agente_emprego_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageModelAdapter());
    }

    if (!Hive.isBoxOpen('chat_history')) {
      await Hive.openBox<MessageModel>('chat_history');
    }
  });

  tearDown(() async {
    await Hive.box<MessageModel>('chat_history').clear();
  });

  tearDownAll(() async {
    await Hive.box<MessageModel>('chat_history').close();
  });

  testWidgets('renderiza a tela inicial do chat', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Agente de Emprego'), findsOneWidget);
    expect(find.textContaining('Seu copiloto para candidaturas'), findsOneWidget);
    expect(find.textContaining('Digite ou cole'), findsOneWidget);
  });
}
