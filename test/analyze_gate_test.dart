import 'package:agente_emprego/data/analyze_gate.dart';
import 'package:agente_emprego/data/repositories/auth_repository_impl.dart';
import 'package:agente_emprego/data/repositories/chat_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyzeGate', () {
    test('so libera quando has_embeddings e true', () {
      expect(AnalyzeGate.canAnalyze(null), isFalse);
      expect(
        AnalyzeGate.canAnalyze(
          const UserStatusData(hasCv: true, hasEmbeddings: false),
        ),
        isFalse,
      );
      expect(
        AnalyzeGate.canAnalyze(
          const UserStatusData(hasCv: false, hasEmbeddings: true),
        ),
        isTrue,
      );
      expect(
        AnalyzeGate.canAnalyze(
          const UserStatusData(hasCv: true, hasEmbeddings: true),
        ),
        isTrue,
      );
    });

    test('explica motivo do bloqueio', () {
      expect(
        AnalyzeGate.blockReason(null),
        AnalyzeGate.waitingStatusMessage,
      );
      expect(
        AnalyzeGate.blockReason(
          const UserStatusData(hasCv: false, hasEmbeddings: false),
        ),
        AnalyzeGate.missingCvMessage,
      );
      expect(
        AnalyzeGate.blockReason(
          const UserStatusData(hasCv: true, hasEmbeddings: false),
        ),
        AnalyzeGate.missingEmbeddingsMessage,
      );
      expect(
        AnalyzeGate.blockReason(
          const UserStatusData(hasCv: true, hasEmbeddings: true),
        ),
        isNull,
      );
    });
  });

  group('ChatRepositoryImpl processar timeouts', () {
    test('POST /processar usa receiveTimeout de 120s', () {
      expect(
        ChatRepositoryImpl.processarReceiveTimeout,
        const Duration(seconds: 120),
      );
      final options = ChatRepositoryImpl.processarRequestOptions(
        headers: const {'Authorization': 'Bearer token'},
      );
      expect(options.receiveTimeout, const Duration(seconds: 120));
      expect(options.sendTimeout, const Duration(seconds: 60));
      expect(options.connectTimeout, const Duration(seconds: 30));
      expect(options.headers?['Authorization'], 'Bearer token');
    });
  });
}
