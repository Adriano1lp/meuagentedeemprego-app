import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/manual_profile_model.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../providers/session_provider.dart';
import 'home_screen.dart';

class ManualProfileScreen extends ConsumerStatefulWidget {
  const ManualProfileScreen({super.key});

  @override
  ConsumerState<ManualProfileScreen> createState() => _ManualProfileScreenState();
}

class _ManualProfileScreenState extends ConsumerState<ManualProfileScreen> {
  static const _ink = Color(0xFF111111);
  static const _paper = Color(0xFFFDFDF7);
  static const _blue = Color(0xFF87D2FF);
  static const _yellow = Color(0xFFFFE16A);
  static const _green = Color(0xFFB6F36A);

  final _repository = UserRepositoryImpl();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _goals = TextEditingController();
  final _seniority = TextEditingController();
  final _workModel = TextEditingController();
  final _availability = TextEditingController();
  final _skills = TextEditingController();
  final _tools = TextEditingController();
  final _languages = TextEditingController();
  final _certifications = TextEditingController();
  final _projects = TextEditingController();
  final _extras = TextEditingController();
  final List<_EducationFields> _educations = [];
  final List<_ExperienceFields> _experiences = [];
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _title, _summary, _goals, _seniority, _workModel, _availability,
      _skills, _tools, _languages, _certifications, _projects, _extras,
    ]) {
      controller.dispose();
    }
    for (final item in _educations) { item.dispose(); }
    for (final item in _experiences) { item.dispose(); }
    super.dispose();
  }

  List<String> _lines(TextEditingController controller) => controller.text
      .split(RegExp(r'[,\n;]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  ManualProfileDraft _draft() => ManualProfileDraft(
    tituloProfissional: _title.text,
    resumoProfissional: _summary.text,
    objetivosProfissionais: _goals.text,
    senioridade: _seniority.text,
    modeloTrabalho: _workModel.text,
    disponibilidade: _availability.text,
    formacoes: _educations.map((item) => item.value).toList(),
    experiencias: _experiences.map((item) => item.value).toList(),
    habilidadesTecnicas: _lines(_skills),
    ferramentas: _lines(_tools),
    idiomas: _lines(_languages),
    certificacoes: _lines(_certifications),
    projetos: _lines(_projects),
    atividadesComplementares: _lines(_extras),
  );

  Future<void> _submit() async {
    final session = ref.read(sessionProvider);
    final token = session.authToken;
    if (token == null || token.trim().isEmpty) {
      _message('Sessao expirada. Entre novamente.');
      return;
    }
    final draft = _draft();
    final error = draft.validate();
    if (error != null) {
      _message(error);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.saveManualProfile(authToken: token, profile: draft.toJson());
      await ref.read(sessionProvider.notifier).updateHasCv(true);
      if (!mounted) return;
      _message('Perfil salvo e preparado para analisar vagas.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro manual')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(
                color: _yellow,
                title: 'Conte sua trajetoria',
                subtitle: 'Use detalhes concretos. Eles ajudam o sistema a comparar seu perfil com as vagas.',
                children: [
                  _field(_title, 'Titulo profissional atual ou desejado'),
                  _field(_summary, 'Resumo profissional *', maxLines: 5),
                  _field(_goals, 'Objetivos e areas de interesse', maxLines: 4),
                  _field(_seniority, 'Senioridade'),
                  _field(_workModel, 'Modelo de trabalho desejado'),
                  _field(_availability, 'Disponibilidade'),
                ],
              ),
              const SizedBox(height: 18),
              _section(
                color: _blue,
                title: 'Formacao academica',
                subtitle: 'Adicione quantas formacoes precisar.',
                children: [
                  for (var index = 0; index < _educations.length; index++)
                    _educationCard(index),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => setState(() => _educations.add(_EducationFields())),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar formacao'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _section(
                color: _paper,
                title: 'Experiencia profissional',
                subtitle: 'Resultados mensuraveis e ferramentas tornam o perfil mais forte.',
                children: [
                  for (var index = 0; index < _experiences.length; index++)
                    _experienceCard(index),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => setState(() => _experiences.add(_ExperienceFields())),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar experiencia'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _section(
                color: _green,
                title: 'Habilidades e qualificacoes',
                subtitle: 'Separe os itens por virgula ou por linha.',
                children: [
                  _field(_skills, 'Habilidades tecnicas', maxLines: 3),
                  _field(_tools, 'Ferramentas, tecnologias e metodos', maxLines: 3),
                  _field(_languages, 'Idiomas e nivel', maxLines: 3),
                  _field(_certifications, 'Certificacoes', maxLines: 3),
                  _field(_projects, 'Projetos relevantes', maxLines: 5),
                  _field(_extras, 'Premios, publicacoes e atividades complementares', maxLines: 4),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_saving ? 'Salvando e processando...' : 'Salvar e preparar analises'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: _box(color),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(subtitle),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  Widget _educationCard(int index) {
    final item = _educations[index];
    return _entryCard(
      title: 'Formacao ${index + 1}',
      onRemove: () { item.dispose(); setState(() => _educations.removeAt(index)); },
      children: [
        _field(item.institution, 'Instituicao *'),
        _field(item.course, 'Curso *'),
        _field(item.degree, 'Grau ou nivel'),
        _field(item.startYear, 'Ano de inicio'),
        _field(item.endYear, 'Ano de conclusao'),
        _field(item.status, 'Status: concluido, cursando ou interrompido'),
        _field(item.details, 'Disciplinas, atividades e conquistas', maxLines: 4),
      ],
    );
  }

  Widget _experienceCard(int index) {
    final item = _experiences[index];
    return _entryCard(
      title: 'Experiencia ${index + 1}',
      onRemove: () { item.dispose(); setState(() => _experiences.removeAt(index)); },
      children: [
        _field(item.company, 'Empresa *'),
        _field(item.role, 'Cargo *'),
        _field(item.area, 'Area'),
        _field(item.startDate, 'Data de inicio'),
        _field(item.endDate, 'Data de fim'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Emprego atual'),
          value: item.current,
          onChanged: (value) => setState(() => item.current = value ?? false),
        ),
        _field(item.activities, 'Principais atividades *', maxLines: 5),
        _field(item.responsibilities, 'Responsabilidades', maxLines: 4),
        _field(item.results, 'Resultados mensuraveis', maxLines: 4),
        _field(item.tools, 'Ferramentas, tecnologias e metodos', maxLines: 3),
        _field(item.keywords, 'Palavras-chave relevantes para ATS', maxLines: 3),
      ],
    );
  }

  Widget _entryCard({required String title, required VoidCallback onRemove, required List<Widget> children}) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: _box(_paper, offset: 4, radius: 16),
    child: Column(
      children: [
        Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          IconButton(onPressed: _saving ? null : onRemove, tooltip: 'Remover', icon: const Icon(Icons.delete_outline)),
        ]),
        ...children,
      ],
    ),
  );

  Widget _field(TextEditingController controller, String label, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: !_saving,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: maxLines > 1),
    ),
  );

  BoxDecoration _box(Color color, {double offset = 7, double radius = 22}) => BoxDecoration(
    color: color,
    border: Border.all(color: _ink, width: 3),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [BoxShadow(color: _ink, offset: Offset(offset, offset))],
  );

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _EducationFields {
  final institution = TextEditingController();
  final course = TextEditingController();
  final degree = TextEditingController();
  final startYear = TextEditingController();
  final endYear = TextEditingController();
  final status = TextEditingController();
  final details = TextEditingController();
  ManualEducation get value => ManualEducation(
    instituicao: institution.text, curso: course.text, grau: degree.text,
    anoInicio: startYear.text, anoConclusao: endYear.text,
    status: status.text, detalhes: details.text,
  );
  void dispose() { for (final item in [institution, course, degree, startYear, endYear, status, details]) { item.dispose(); } }
}

class _ExperienceFields {
  final company = TextEditingController();
  final role = TextEditingController();
  final area = TextEditingController();
  final startDate = TextEditingController();
  final endDate = TextEditingController();
  final activities = TextEditingController();
  final responsibilities = TextEditingController();
  final results = TextEditingController();
  final tools = TextEditingController();
  final keywords = TextEditingController();
  bool current = false;
  ManualExperience get value => ManualExperience(
    empresa: company.text, cargo: role.text, area: area.text,
    dataInicio: startDate.text, dataFim: endDate.text, empregoAtual: current,
    atividades: activities.text, responsabilidades: responsibilities.text,
    resultados: results.text, ferramentas: tools.text, palavrasChave: keywords.text,
  );
  void dispose() { for (final item in [company, role, area, startDate, endDate, activities, responsibilities, results, tools, keywords]) { item.dispose(); } }
}
