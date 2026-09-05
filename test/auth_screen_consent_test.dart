import 'dart:io';

import 'package:agente_emprego/data/legal_versions.dart';
import 'package:agente_emprego/data/models/message_model.dart';
import 'package:agente_emprego/data/repositories/legal_repository_impl.dart';
import 'package:agente_emprego/data/token_store.dart';
import 'package:agente_emprego/presentation/providers/consent_provider.dart';
import 'package:agente_emprego/presentation/screens/auth_screen.dart';
import 'package:agente_emprego/presentation/screens/consent_reaccept_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/session_test_harness.dart';

class _FakeLegalRepository implements LegalRepository {
  final List<Map<String, String>> consentCalls = [];

  @override
  Future<LegalDocumentData> fetchDocument(
    LegalDoc doc, {
    String? version,
  }) async {
    return LegalDocumentData(
      doc: doc,
      version: version ?? doc.currentVersion,
      markdown: 'Texto vigente de ${doc.title} v${version ?? doc.currentVersion}',
    );
  }

  @override
  Future<void> acceptConsent({
    required String authToken,
    required LegalDoc doc,
    String? version,
  }) async {
    consentCalls.add(buildConsentRequest(doc, version: version));
  }
}

void main() {
  late _FakeLegalRepository legalRepository;
  late MemoryTokenStore tokenStore;

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
    legalRepository = _FakeLegalRepository();
    tokenStore = bindTestTokenStore();
    await Hive.box<MessageModel>('chat_history').clear();
    await Hive.box<String>('app_session').clear();
  });

  tearDownAll(() async {
    await Hive.box<MessageModel>('chat_history').close();
    await Hive.box<String>('app_session').close();
  });

  Widget wrap(Widget child) {
    return testProviderScope(
      tokenStore: tokenStore,
      overrides: [
        legalRepositoryProvider.overrideWithValue(legalRepository),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('signup mostra os docs, checkboxes desmarcados e bloqueia criar conta', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const AuthScreen()));

    await tester.tap(find.text('Criar conta').first);
    await tester.pumpAndSettle();

    expect(find.text('GET /legal/terms?version=1.0'), findsOneWidget);
    expect(find.text('GET /legal/privacy?version=1.0'), findsOneWidget);
    expect(find.text('Texto vigente de Termos de uso v1.0'), findsOneWidget);
    expect(
      find.text('Texto vigente de Politica de privacidade v1.0'),
      findsOneWidget,
    );

    final termsCheckbox = tester.widget<Checkbox>(
      find.byKey(const ValueKey('termsAcceptCheckbox')),
    );
    final privacyCheckbox = tester.widget<Checkbox>(
      find.byKey(const ValueKey('privacyAcceptCheckbox')),
    );
    expect(termsCheckbox.value, isFalse);
    expect(privacyCheckbox.value, isFalse);

    final createButton = find.byKey(const ValueKey('createAccountButton'));
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('termsAcceptCheckbox')));
    await tester.tap(find.byKey(const ValueKey('termsAcceptCheckbox')));
    await tester.pump();
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('privacyAcceptCheckbox')));
    await tester.tap(find.byKey(const ValueKey('privacyAcceptCheckbox')));
    await tester.pump();
    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
  });

  testWidgets('reaceite mostra o texto vigente e so libera depois do checkbox', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const _ConsentReacceptHarness()));
    await tester.pumpAndSettle();

    expect(find.text('Atualizar aceites'), findsOneWidget);
    expect(find.text('GET /legal/terms?version=1.0'), findsOneWidget);
    expect(find.text('Texto vigente de Termos de uso v1.0'), findsOneWidget);
    expect(find.byKey(const ValueKey('privacyAcceptCheckbox')), findsNothing);

    final termsCheckbox = tester.widget<Checkbox>(
      find.byKey(const ValueKey('termsAcceptCheckbox')),
    );
    expect(termsCheckbox.value, isFalse);

    final reacceptButton = find.byKey(const ValueKey('reacceptConsentButton'));
    expect(tester.widget<FilledButton>(reacceptButton).onPressed, isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('termsAcceptCheckbox')));
    await tester.tap(find.byKey(const ValueKey('termsAcceptCheckbox')));
    await tester.pump();
    expect(tester.widget<FilledButton>(reacceptButton).onPressed, isNotNull);
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
