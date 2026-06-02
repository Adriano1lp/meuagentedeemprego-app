class JobDescriptionValidationResult {
  final bool isValid;
  final String? message;

  const JobDescriptionValidationResult._({
    required this.isValid,
    this.message,
  });

  const JobDescriptionValidationResult.valid()
      : this._(isValid: true);

  const JobDescriptionValidationResult.invalid(String message)
      : this._(isValid: false, message: message);
}

class JobDescriptionValidator {
  static const String invalidMessage =
      'Cole uma descricao de vaga com cargo, requisitos ou responsabilidades para iniciar a analise.';

  static const int _minimumLength = 80;
  static const Set<String> _jobSignals = {
    'vaga',
    'cargo',
    'responsabilidades',
    'responsabilidade',
    'requisitos',
    'requisito',
    'qualificacoes',
    'qualificacao',
    'atividades',
    'atividade',
    'empresa',
    'beneficios',
    'beneficio',
    'experiencia',
    'contratacao',
    'clt',
    'pj',
    'remoto',
    'hibrido',
    'presencial',
    'junior',
    'pleno',
    'senior',
    'estagio',
  };

  static const Set<String> _strongSignals = {
    'responsabilidades',
    'responsabilidade',
    'requisitos',
    'requisito',
    'qualificacoes',
    'qualificacao',
    'atividades',
    'atividade',
  };

  static JobDescriptionValidationResult validate(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty || normalized.length < _minimumLength) {
      return const JobDescriptionValidationResult.invalid(invalidMessage);
    }

    final matchedSignals = _jobSignals
        .where((signal) => _containsWholeWord(normalized, signal))
        .toSet();
    final hasStrongSignal = matchedSignals.any(_strongSignals.contains);

    if (matchedSignals.length >= 3 ||
        (hasStrongSignal && matchedSignals.length >= 2)) {
      return const JobDescriptionValidationResult.valid();
    }

    return const JobDescriptionValidationResult.invalid(invalidMessage);
  }

  static String _normalize(String text) {
    final lower = text.toLowerCase();
    const replacements = {
      '\u00e1': 'a',
      '\u00e0': 'a',
      '\u00e2': 'a',
      '\u00e3': 'a',
      '\u00e4': 'a',
      '\u00e9': 'e',
      '\u00e8': 'e',
      '\u00ea': 'e',
      '\u00eb': 'e',
      '\u00ed': 'i',
      '\u00ec': 'i',
      '\u00ee': 'i',
      '\u00ef': 'i',
      '\u00f3': 'o',
      '\u00f2': 'o',
      '\u00f4': 'o',
      '\u00f5': 'o',
      '\u00f6': 'o',
      '\u00fa': 'u',
      '\u00f9': 'u',
      '\u00fb': 'u',
      '\u00fc': 'u',
      '\u00e7': 'c',
    };

    return lower
        .split('')
        .map((character) => replacements[character] ?? character)
        .join()
        .trim();
  }

  static bool _containsWholeWord(String text, String word) {
    return RegExp('(^|[^a-z0-9])$word([^a-z0-9]|\$)').hasMatch(text);
  }
}
