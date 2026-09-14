import 'repositories/auth_repository_impl.dart';

/// Client-side gate for Analisar vaga. Mirrors web `canAnalyzeVaga`:
/// only `has_embeddings` from GET /users/me/status enables POST /processar.
class AnalyzeGate {
  static const waitingStatusMessage =
      'Aguarde o status do curriculo para analisar a vaga.';
  static const missingCvMessage =
      'Sem curriculo valido. Envie um PDF ou TXT para habilitar Analisar vaga.';
  static const missingEmbeddingsMessage =
      'Embeddings ainda nao estao prontos. Envie o curriculo e aguarde o processamento.';

  static bool canAnalyze(UserStatusData? status) {
    return status?.hasEmbeddings == true;
  }

  static String? blockReason(UserStatusData? status) {
    if (canAnalyze(status)) {
      return null;
    }
    if (status == null) {
      return waitingStatusMessage;
    }
    if (!status.hasCv) {
      return missingCvMessage;
    }
    return missingEmbeddingsMessage;
  }
}
