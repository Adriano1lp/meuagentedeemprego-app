import 'analyze_gate.dart';
import 'repositories/auth_repository_impl.dart';

/// Client-side gate for Carta. Same signal as Analisar vaga:
/// only `has_embeddings` from GET /users/me/status enables generation.
class CoverLetterGate {
  static const waitingStatusMessage =
      'Aguarde o status do curriculo para gerar a carta.';

  static const statusErrorMessage =
      'Nao foi possivel verificar o curriculo. Tente novamente.';

  static const updateCvMessage =
      'Envie ou atualize o curriculo para gerar a carta.';

  static bool canGenerate(UserStatusData? status) {
    return AnalyzeGate.canAnalyze(status);
  }

  /// Null when generation is allowed. Null status means the check has not
  /// finished; a failed check uses [statusErrorMessage] in the screen.
  static String? blockMessage(UserStatusData? status) {
    if (canGenerate(status)) {
      return null;
    }
    if (status == null) {
      return waitingStatusMessage;
    }
    return updateCvMessage;
  }
}
