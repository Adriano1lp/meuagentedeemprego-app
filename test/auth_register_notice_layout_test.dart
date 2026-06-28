import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:meu_agente_de_emprego/data/models/message_model.dart';
import 'package:meu_agente_de_emprego/domain/terms/usage_terms.dart';
import 'package:meu_agente_de_emprego/presentation/screens/auth_screen.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'auth_register_notice_layout_test',
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

  tearDown(() async {
    await Hive.box<MessageModel>('chat_history').clear();
    await Hive.box<String>('app_session').clear();
  });

  tearDownAll(() async {
    await Hive.box<MessageModel>('chat_history').close();
    await Hive.box<String>('app_session').close();
  });

  testWidgets(
    'aviso de termo na criacao de conta usa caixa legivel sem formato oval',
    (WidgetTester tester) async {
      await _pumpRegisterTab(tester, const Size(320, 640));
      _expectNoticeBox(tester, minWidth: 200);
      expect(tester.takeException(), isNull);

      await _pumpRegisterTab(tester, const Size(900, 720));
      _expectNoticeBox(tester, minWidth: 600);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpRegisterTab(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(home: AuthScreen())),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(Tab, 'Criar conta'));
  await tester.pumpAndSettle();
}

void _expectNoticeBox(WidgetTester tester, {required double minWidth}) {
  final finder = find.byKey(const Key('register-usage-terms-notice'));

  expect(finder, findsOneWidget);
  expect(find.text(usageTermsText), findsOneWidget);

  final notice = tester.widget<Container>(finder);
  final decoration = notice.decoration! as BoxDecoration;

  expect(decoration.borderRadius, BorderRadius.circular(18));
  expect(decoration.border?.top.width, 2);
  expect(tester.getSize(finder).width, greaterThan(minWidth));
}
