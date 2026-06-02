import 'package:agente_emprego/data/repositories/chat_repository_impl.dart';
import 'package:agente_emprego/domain/entities/chat_message.dart';
import 'package:agente_emprego/presentation/providers/chat_provider.dart';
import 'package:agente_emprego/presentation/validators/job_description_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JobDescriptionValidator', () {
    test('bloqueia textos genericos', () {
      for (final text in ['oi', 'teste', 'me ajuda', 'quero emprego']) {
        final result = JobDescriptionValidator.validate(text);

        expect(result.isValid, isFalse);
        expect(result.message, JobDescriptionValidator.invalidMessage);
      }
    });

    test('aceita descricao de vaga com cargo requisitos e responsabilidades', () {
      const text = '''
Vaga para Desenvolvedor Flutter Pleno em empresa de tecnologia.
Responsabilidades: desenvolver telas, integrar APIs REST e colaborar com o time de produto.
Requisitos: experiencia com Flutter, Dart, Git, testes automatizados e consumo de APIs.
Modelo de contratacao CLT remoto com beneficios.
''';

      final result = JobDescriptionValidator.validate(text);

      expect(result.isValid, isTrue);
      expect(result.message, isNull);
    });
  });

  group('ChatNotifier', () {
    test('nao chama repository quando texto nao parece vaga', () async {
      final repository = _FakeChatRepository();
      final notifier = ChatNotifier(repository);

      final wasAccepted = await notifier.sendMessage('quero emprego');

      expect(wasAccepted, isFalse);
      expect(repository.sendMessageCalls, 0);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.errorMessage, JobDescriptionValidator.invalidMessage);
    });

    test('chama repository quando texto parece vaga', () async {
      final repository = _FakeChatRepository();
      final notifier = ChatNotifier(repository);

      final wasAccepted = await notifier.sendMessage('''
Vaga para Analista de Dados Senior.
Responsabilidades: construir dashboards, analisar indicadores e apoiar decisoes de negocio.
Requisitos: experiencia com SQL, Power BI, Python e comunicacao com areas de produto.
Contratacao PJ hibrido com beneficios e bonus por performance.
''');

      expect(wasAccepted, isTrue);
      expect(repository.sendMessageCalls, 1);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.messages.length, 2);
      expect(notifier.state.errorMessage, isNull);
    });
  });
}

class _FakeChatRepository implements ChatRepositoryImpl {
  int sendMessageCalls = 0;
  final List<ChatMessage> savedMessages = [];

  @override
  List<ChatMessage> getHistory() => [];

  @override
  Future<void> saveToDisk(ChatMessage message) async {
    savedMessages.add(message);
  }

  @override
  Future<ChatMessage> sendMessage(String text) async {
    sendMessageCalls++;
    return ChatMessage(
      id: 'agent-response',
      text: 'Analise gerada',
      isUser: false,
      timestamp: DateTime(2026),
    );
  }
}
