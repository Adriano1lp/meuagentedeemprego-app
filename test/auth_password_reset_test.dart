import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:meu_agente_de_emprego/data/models/message_model.dart';
import 'package:meu_agente_de_emprego/data/repositories/auth_repository_impl.dart';
import 'package:meu_agente_de_emprego/presentation/screens/auth_screen.dart';

void main() {
  late _FakeAuthRepository repository;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'auth_password_reset_test',
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

  setUp(() {
    repository = _FakeAuthRepository();
  });

  tearDown(() async {
    await Hive.box<MessageModel>('chat_history').clear();
    await Hive.box<String>('app_session').clear();
  });

  tearDownAll(() async {
    await Hive.box<MessageModel>('chat_history').close();
    await Hive.box<String>('app_session').close();
  });

  testWidgets('recuperacao de senha valida email, senha e confirma sucesso', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: AuthScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Esqueci minha senha'), findsOneWidget);

    await tester.ensureVisible(find.text('Esqueci minha senha'));
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    expect(find.text('Recuperar senha'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email cadastrado'),
      'email-invalido',
    );
    await tester.tap(find.text('Enviar'));
    await tester.pump();
    expect(find.text('Informe um email valido.'), findsOneWidget);
    expect(repository.requestCalls, 0);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email cadastrado'),
      'maria@example.com',
    );
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(repository.requestCalls, 1);
    expect(repository.requestedEmail, 'maria@example.com');
    expect(find.text('Definir nova senha'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nova senha com pelo menos 8 caracteres'),
      'curta',
    );
    await tester.tap(find.text('Redefinir'));
    await tester.pump();
    expect(repository.confirmCalls, 0);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nova senha com pelo menos 8 caracteres'),
      'senha-nova-123',
    );
    await tester.tap(find.text('Redefinir'));
    await tester.pumpAndSettle();

    expect(repository.confirmCalls, 1);
    expect(repository.confirmedToken, 'token-de-teste');
    expect(repository.confirmedPassword, 'senha-nova-123');
    expect(find.text('Definir nova senha'), findsNothing);
  });
}

class _FakeAuthRepository extends AuthRepositoryImpl {
  int requestCalls = 0;
  int confirmCalls = 0;
  String? requestedEmail;
  String? confirmedToken;
  String? confirmedPassword;

  @override
  Future<PasswordResetRequestData> requestPasswordReset({
    required String email,
  }) async {
    requestCalls += 1;
    requestedEmail = email;
    return const PasswordResetRequestData(
      message:
          'Se o email estiver cadastrado, enviaremos instrucoes para recuperar a senha.',
      resetToken: 'token-de-teste',
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    confirmCalls += 1;
    confirmedToken = token;
    confirmedPassword = newPassword;
  }
}
