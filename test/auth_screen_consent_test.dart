import 'dart:io';

import 'package:agente_emprego/data/consent_outdated.dart';
import 'package:agente_emprego/data/legal_versions.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/presentation/providers/consent_provider.dart';
import 'package:agente_emprego/presentation/screens/auth_screen.dart';
import 'package:agente_emprego/presentation/widgets/consent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('consent_ui_test');
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
    await Hive.box<MessageModel>('chat_history').clear();
    await Hive.box<String>('app_session').clear();
  });

  tearDownAll(() async {
    await Hive.box<MessageModel>('chat_history').close();
    await Hive.box<String>('app_session').close();
  });

  testWidgets('signup exige os dois checkboxes antes de criar conta', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthScreen()),
      ),
    );

    await tester.tap(find.text('Criar conta').first);
    await tester.pumpAndSettle();

    final createButton = find.byKey(const ValueKey('createAccountButton'));
    final termsCheckbox = find.byKey(const ValueKey('termsAcceptCheckbox'));
    final privacyCheckbox = find.byKey(const ValueKey('privacyAcceptCheckbox'));

    await tester.ensureVisible(createButton);
    expect(createButton, findsOneWidget);
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
    expect(termsCheckbox, findsOneWidget);
    expect(privacyCheckbox, findsOneWidget);
    expect(find.byKey(const ValueKey('openTermsLink')), findsOneWidget);
    expect(find.byKey(const ValueKey('openPrivacyLink')), findsOneWidget);

    await tester.ensureVisible(termsCheckbox);
    await tester.tap(termsCheckbox);
    await tester.pump();
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    await tester.ensureVisible(privacyCheckbox);
    await tester.tap(privacyCheckbox);
    await tester.pump();
    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
  });

  testWidgets('gate bloqueia o app quando o consentimento esta desatualizado', (
    WidgetTester tester,
  ) async {
    final session = Hive.box<String>('app_session');
    await session.put('auth_token', 'token');
    await session.put('user_id', 'user_1');
    await session.put('email', 'user@example.com');
    await session.put('display_name', 'Usuario Teste');
    await session.put('has_cv', 'true');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) {
            return ConsentGate(child: child ?? const SizedBox.shrink());
          },
          home: const Scaffold(body: Text('APP_LIBERADO')),
        ),
      ),
    );

    expect(find.text('APP_LIBERADO'), findsOneWidget);

    final context = tester.element(find.text('APP_LIBERADO'));
    ProviderScope.containerOf(context).read(consentProvider.notifier).applyException(
      const ConsentOutdatedException(
        doc: LegalDoc.terms,
        code: ConsentOutdatedException.termsCode,
        message: 'Termos desatualizados',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('APP_LIBERADO'), findsNothing);
    expect(find.text('Atualizar aceites'), findsOneWidget);
    expect(find.text('Aceitar e continuar'), findsOneWidget);
  });
}
