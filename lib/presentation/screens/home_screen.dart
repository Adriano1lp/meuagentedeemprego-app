import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_provider.dart';
import '../widgets/app_drawer.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'job_search_screen.dart';
import 'user_registration_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _pink = Color(0xFFFF5D8F);
  static const Color _blue = Color(0xFF87D2FF);
  static const Color _yellow = Color(0xFFFFE16A);
  static const Color _green = Color(0xFFB6F36A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final name = session.displayName ?? 'Usuario';

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Home'),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(26),
                decoration: _brutalBox(_yellow),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: _chipBox(_paper),
                      child: Text(
                        'Conta autenticada',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Ola, $name',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Escolha uma acao para continuar: analisar uma vaga, revisar historico, buscar oportunidades ou atualizar seu curriculo.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Atalhos',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _ActionTile(
                color: _green,
                icon: Icons.analytics_outlined,
                title: 'Analise de vaga',
                subtitle: 'Cole uma descricao de vaga e receba aderencia, gaps e PDF.',
                onTap: () => _open(context, const ChatScreen()),
              ),
              _ActionTile(
                color: _blue,
                icon: Icons.history,
                title: 'Historico',
                subtitle: 'Revise respostas e documentos gerados anteriormente.',
                onTap: () => _open(context, const HistoryScreen()),
              ),
              _ActionTile(
                color: _pink,
                icon: Icons.travel_explore_rounded,
                title: 'Buscar vagas',
                subtitle: 'Pesquise oportunidades e abra links externos.',
                onTap: () => _open(context, const JobSearchScreen()),
              ),
              _ActionTile(
                color: _paper,
                icon: Icons.badge_outlined,
                title: 'Curriculo',
                subtitle: 'Atualize o curriculo e reconstrua os embeddings.',
                onTap: () => _open(context, const UserRegistrationScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static BoxDecoration _brutalBox(
    Color color, {
    double radius = 24,
    double offset = 8,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _ink, width: 3),
      boxShadow: [BoxShadow(color: _ink, offset: Offset(offset, offset))],
    );
  }

  static BoxDecoration _chipBox(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _ink, width: 2),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(3, 3))],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: HomeScreen._brutalBox(
              color,
              radius: 22,
              offset: 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HomeScreen._paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HomeScreen._ink, width: 2),
                  ),
                  child: Icon(icon, color: HomeScreen._ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: HomeScreen._ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
