import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_drawer.dart';

class JobSearchScreen extends StatefulWidget {
  const JobSearchScreen({super.key});

  @override
  State<JobSearchScreen> createState() => _JobSearchScreenState();
}

class _JobSearchScreenState extends State<JobSearchScreen> {
  static const Color _canvas = Color(0xFFFFF6E9);
  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _pink = Color(0xFFFF5D8F);
  static const Color _blue = Color(0xFF87D2FF);
  static const Color _yellow = Color(0xFFFFE16A);
  static const Color _green = Color(0xFFB6F36A);

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const List<_JobVacancy> _allVacancies = [
    _JobVacancy(
      title: 'Desenvolvedor Flutter',
      company: 'Nexa Talent',
      location: 'Remoto',
      summary:
          'Atuacao em app mobile com Flutter, integracao com APIs e foco em UX.',
      link: 'https://www.linkedin.com/jobs/',
      accent: _pink,
    ),
    _JobVacancy(
      title: 'Analista de Dados',
      company: 'Insight Lab',
      location: 'Sao Paulo, SP',
      summary:
          'Analise de indicadores, SQL, dashboards e apoio a decisoes de negocio.',
      link: 'https://www.linkedin.com/jobs/',
      accent: _blue,
    ),
    _JobVacancy(
      title: 'Product Designer',
      company: 'Studio Pixel',
      location: 'Hibrido',
      summary:
          'Pesquisa com usuarios, prototipacao e desenho de jornadas para produtos digitais.',
      link: 'https://www.linkedin.com/jobs/',
      accent: _yellow,
    ),
    _JobVacancy(
      title: 'Engenheiro de Backend',
      company: 'Orbit Cloud',
      location: 'Remoto',
      summary:
          'APIs escalaveis em Python, observabilidade, filas e arquitetura distribuida.',
      link: 'https://www.linkedin.com/jobs/',
      accent: _green,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vacancies = _filteredVacancies;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Buscar vagas'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(color: _canvas),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _yellow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _ink, width: 3),
                  boxShadow: const [
                    BoxShadow(color: _ink, offset: Offset(8, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receba vagas no seu tema',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Digite a vaga desejada no campo abaixo. Os cards encontrados aparecem logo em seguida com o link direto.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: _paper,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _ink, width: 3),
                        boxShadow: const [
                          BoxShadow(color: _ink, offset: Offset(6, 6)),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _query = value.trim();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Ex.: Flutter, analista de dados, designer...',
                          prefixIcon: Icon(Icons.search_rounded),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                vacancies.isEmpty
                    ? 'Nenhuma vaga encontrada'
                    : '${vacancies.length} vagas encontradas',
                style: theme.textTheme.titleMedium?.copyWith(color: _ink),
              ),
              const SizedBox(height: 12),
              if (vacancies.isEmpty)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _paper,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _ink, width: 3),
                    boxShadow: const [
                      BoxShadow(color: _ink, offset: Offset(6, 6)),
                    ],
                  ),
                  child: Text(
                    'Tente buscar por outro termo para ver novas oportunidades.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: _ink),
                  ),
                )
              else
                ...vacancies.map(
                  (vacancy) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _JobCard(
                      vacancy: vacancy,
                      onOpen: () => _openVacancyLink(vacancy.link),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<_JobVacancy> get _filteredVacancies {
    if (_query.isEmpty) return _allVacancies;

    final normalizedQuery = _query.toLowerCase();
    return _allVacancies.where((vacancy) {
      final haystack =
          '${vacancy.title} ${vacancy.company} ${vacancy.location} ${vacancy.summary}'
              .toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList();
  }

  Future<void> _openVacancyLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('Link da vaga invalido.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      _showMessage('Nao foi possivel abrir o link da vaga.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _JobCard extends StatelessWidget {
  final _JobVacancy vacancy;
  final VoidCallback onOpen;

  const _JobCard({
    required this.vacancy,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: vacancy.accent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF111111), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xFF111111), offset: Offset(6, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vacancy.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${vacancy.company}  •  ${vacancy.location}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFDF7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF111111), width: 2),
                ),
                child: Text(
                  'Link',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            vacancy.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFDFDF7),
                foregroundColor: const Color(0xFF111111),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(vacancy.link),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobVacancy {
  final String title;
  final String company;
  final String location;
  final String summary;
  final String link;
  final Color accent;

  const _JobVacancy({
    required this.title,
    required this.company,
    required this.location,
    required this.summary,
    required this.link,
    required this.accent,
  });
}
