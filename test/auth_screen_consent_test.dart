import 'dart:io';

import 'package:agente_emprego/data/legal_versions.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/presentation/providers/consent_provider.dart';
import 'package:agente_emprego/presentation/screens/auth_screen.dart';
import 'package:agente_emprego/presentation/screens/consent_reaccept_screen.dart';
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

    expect(createButton, findsOneWidget);
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
    expect(termsCheckbox, findsOneWidget);
    expect(privacyCheckbox, findsOneWidget);
    expect(find.byKey(const ValueKey('openTermsLink')), findsOneWidget);
    expect(find.byKey(const ValueKey('openPrivacyLink')), findsOneWidget);

    await tester.tap(termsCheckbox);
    await tester.pump();
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    await tester.tap(privacyCheckbox);
    await tester.pump();
    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
  });

  testWidgets('tela de reaceite pede os documentos desatualizados', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: _ConsentReacceptHarness()),
      ),
    );
    await tester.pump();

    expect(find.text('Atualizar aceites'), findsOneWidget);
    expect(find.byKey(const ValueKey('termsAcceptCheckbox')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacyAcceptCheckbox')), findsNothing);
    expect(find.byKey(const ValueKey('reacceptConsentButton')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('reacceptConsentButton')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('termsAcceptCheckbox')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('reacceptConsentButton')))
          .onPressed,
      isNotNull,
    );
  });
}

class _ConsentReacceptHarness extends ConsumerStatefulWidget {
  const _ConsentReacceptHarness();

  @override
  ConsumerState<_ConsentReacceptHarness> createState() =>
      _ConsentReacceptHarnessState();
}

class _ConsentReacceptHarnessState
    extends ConsumerState<_ConsentReacceptHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(consentProvider.notifier).applyFromUser(
        termsVersion: '0.9',
        privacyVersion: CURRENT_PRIVACY_VERSION,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ConsentReacceptScreen();
  }
}
