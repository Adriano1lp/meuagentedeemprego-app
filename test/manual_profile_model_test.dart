import 'package:flutter_test/flutter_test.dart';
import 'package:meu_agente_de_emprego/data/models/manual_profile_model.dart';

void main() {
  test('bloqueia perfil manual vazio ou insuficiente', () {
    final draft = ManualProfileDraft(resumoProfissional: 'Muito curto');

    expect(draft.validate(), contains('pelo menos 30 caracteres'));
  });

  test('bloqueia perfil sem formacao ou experiencia', () {
    final draft = ManualProfileDraft(
      resumoProfissional:
          'Profissional de tecnologia com experiencia e objetivo bem definido.',
    );

    expect(draft.validate(), contains('pelo menos uma formacao ou experiencia'));
  });

  test('aceita perfil valido e serializa dados estruturados', () {
    final draft = ManualProfileDraft(
      tituloProfissional: 'Desenvolvedora backend',
      resumoProfissional:
          'Desenvolvedora backend com experiencia em APIs e bancos de dados.',
      formacoes: [
        ManualEducation(
          instituicao: 'Universidade Exemplo',
          curso: 'Ciencia da Computacao',
          anoConclusao: '2024',
        ),
      ],
      habilidadesTecnicas: const ['Python', 'SQL'],
    );

    expect(draft.validate(), isNull);
    expect(draft.toJson()['formacoes'][0]['instituicao'], 'Universidade Exemplo');
    expect(draft.toJson()['habilidades_tecnicas'], ['Python', 'SQL']);
  });

  test('exige atividades detalhadas na experiencia', () {
    final draft = ManualProfileDraft(
      resumoProfissional:
          'Profissional de tecnologia com experiencia e objetivo bem definido.',
      experiencias: [
        ManualExperience(
          empresa: 'ACME',
          cargo: 'Analista',
          atividades: 'Pouco detalhe',
        ),
      ],
    );

    expect(draft.validate(), contains('pelo menos 20 caracteres'));
  });
}
