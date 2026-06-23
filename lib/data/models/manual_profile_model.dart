class ManualEducation {
  ManualEducation({
    required this.instituicao,
    required this.curso,
    this.grau = '',
    this.anoInicio = '',
    this.anoConclusao = '',
    this.status = '',
    this.detalhes = '',
  });

  final String instituicao;
  final String curso;
  final String grau;
  final String anoInicio;
  final String anoConclusao;
  final String status;
  final String detalhes;

  Map<String, dynamic> toJson() => {
    'instituicao': instituicao.trim(),
    'curso': curso.trim(),
    'grau': grau.trim(),
    'ano_inicio': anoInicio.trim(),
    'ano_conclusao': anoConclusao.trim(),
    'status': status.trim(),
    'detalhes': detalhes.trim(),
  };
}

class ManualExperience {
  ManualExperience({
    required this.empresa,
    required this.cargo,
    required this.atividades,
    this.area = '',
    this.dataInicio = '',
    this.dataFim = '',
    this.empregoAtual = false,
    this.responsabilidades = '',
    this.resultados = '',
    this.ferramentas = '',
    this.palavrasChave = '',
  });

  final String empresa;
  final String cargo;
  final String area;
  final String dataInicio;
  final String dataFim;
  final bool empregoAtual;
  final String atividades;
  final String responsabilidades;
  final String resultados;
  final String ferramentas;
  final String palavrasChave;

  Map<String, dynamic> toJson() => {
    'empresa': empresa.trim(),
    'cargo': cargo.trim(),
    'area': area.trim(),
    'data_inicio': dataInicio.trim(),
    'data_fim': dataFim.trim(),
    'emprego_atual': empregoAtual,
    'atividades': atividades.trim(),
    'responsabilidades': responsabilidades.trim(),
    'resultados': resultados.trim(),
    'ferramentas': ferramentas.trim(),
    'palavras_chave': palavrasChave.trim(),
  };
}

class ManualProfileDraft {
  ManualProfileDraft({
    this.tituloProfissional = '',
    this.resumoProfissional = '',
    this.objetivosProfissionais = '',
    this.senioridade = '',
    this.modeloTrabalho = '',
    this.disponibilidade = '',
    this.formacoes = const [],
    this.experiencias = const [],
    this.habilidadesTecnicas = const [],
    this.ferramentas = const [],
    this.idiomas = const [],
    this.certificacoes = const [],
    this.projetos = const [],
    this.atividadesComplementares = const [],
  });

  final String tituloProfissional;
  final String resumoProfissional;
  final String objetivosProfissionais;
  final String senioridade;
  final String modeloTrabalho;
  final String disponibilidade;
  final List<ManualEducation> formacoes;
  final List<ManualExperience> experiencias;
  final List<String> habilidadesTecnicas;
  final List<String> ferramentas;
  final List<String> idiomas;
  final List<String> certificacoes;
  final List<String> projetos;
  final List<String> atividadesComplementares;

  String? validate() {
    final summary = '${resumoProfissional.trim()} ${objetivosProfissionais.trim()}'.trim();
    if (summary.length < 30) {
      return 'Escreva um resumo profissional ou objetivo com pelo menos 30 caracteres.';
    }
    if (formacoes.isEmpty && experiencias.isEmpty) {
      return 'Adicione pelo menos uma formacao ou experiencia profissional.';
    }
    for (final item in formacoes) {
      if (item.instituicao.trim().isEmpty || item.curso.trim().isEmpty) {
        return 'Informe instituicao e curso em todas as formacoes.';
      }
    }
    for (final item in experiencias) {
      if (item.empresa.trim().isEmpty || item.cargo.trim().isEmpty) {
        return 'Informe empresa e cargo em todas as experiencias.';
      }
      if (item.atividades.trim().length < 20) {
        return 'Descreva as atividades de cada experiencia com pelo menos 20 caracteres.';
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'titulo_profissional': tituloProfissional.trim(),
    'resumo_profissional': resumoProfissional.trim(),
    'objetivos_profissionais': objetivosProfissionais.trim(),
    'senioridade': senioridade.trim(),
    'modelo_trabalho': modeloTrabalho.trim(),
    'disponibilidade': disponibilidade.trim(),
    'formacoes': formacoes.map((item) => item.toJson()).toList(),
    'experiencias': experiencias.map((item) => item.toJson()).toList(),
    'habilidades_tecnicas': habilidadesTecnicas,
    'ferramentas': ferramentas,
    'idiomas': idiomas,
    'certificacoes': certificacoes,
    'projetos': projetos,
    'atividades_complementares': atividadesComplementares,
  };
}
