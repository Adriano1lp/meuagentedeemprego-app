import 'package:agente_emprego/data/cover_letter_gate.dart';
import 'package:agente_emprego/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoverLetterGate', () {
    test('so libera quando has_embeddings e true', () {
      expect(CoverLetterGate.canGenerate(null), isFalse);
      expect(
        CoverLetterGate.canGenerate(
          const UserStatusData(hasCv: true, hasEmbeddings: false),
        ),
        isFalse,
      );
      expect(
        CoverLetterGate.canGenerate(
          const UserStatusData(hasCv: false, hasEmbeddings: false),
        ),
        isFalse,
      );
      expect(
        CoverLetterGate.canGenerate(
          const UserStatusData(hasCv: true, hasEmbeddings: true),
        ),
        isTrue,
      );
    });

    test('pede upload ou atualizacao quando nao ha embeddings', () {
      expect(
        CoverLetterGate.blockMessage(
          const UserStatusData(hasCv: true, hasEmbeddings: false),
        ),
        CoverLetterGate.updateCvMessage,
      );
      expect(
        CoverLetterGate.blockMessage(
          const UserStatusData(hasCv: false, hasEmbeddings: false),
        ),
        CoverLetterGate.updateCvMessage,
      );
      expect(
        CoverLetterGate.blockMessage(
          const UserStatusData(hasCv: true, hasEmbeddings: true),
        ),
        isNull,
      );
      expect(
        CoverLetterGate.blockMessage(null),
        CoverLetterGate.waitingStatusMessage,
      );
    });
  });
}
