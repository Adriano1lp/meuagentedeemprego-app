import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/consent_provider.dart';
import '../providers/session_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/cover_letter_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/job_search_screen.dart';
import '../screens/user_registration_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static const Color _canvas = Color(0xFFFFF6E9);
  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _pink = Color(0xFFFF5D8F);
  static const Color _yellow = Color(0xFFFFE16A);
  static const Color _green = Color(0xFFB6F36A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final userId = session.userId;
    final displayName = session.displayName;
    final email = session.email;

    return Drawer(
      child: Container(
        color: _canvas,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              decoration: const BoxDecoration(
                color: _pink,
                border: Border(bottom: BorderSide(color: _ink, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _paper,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _ink, width: 3),
                      boxShadow: const [
                        BoxShadow(color: _ink, offset: Offset(4, 4)),
                      ],
                    ),
                    child: const Icon(Icons.work_history_outlined, color: _ink),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Agente de Emprego',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: _ink),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Visual bruto, mensagens claras e suporte direto para candidatura, curriculo e outreach.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: _ink),
                  ),
                  if (userId != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _paper,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _ink, width: 2),
                      ),
                      child: Text(
                        'Conta: ${displayName ?? userId}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: _ink),
                      ),
                    ),
                    if (email != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        email,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: _ink),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                child: Column(
                  children: [
                    _DrawerTile(
                      color: _green,
                      icon: Icons.home_rounded,
                      title: 'Home',
                      subtitle: 'Voltar para a tela principal',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _DrawerTile(
                      color: _yellow,
                      icon: Icons.analytics_outlined,
                      title: 'Analise de vaga',
                      subtitle: 'Calcular aderencia, gaps e curriculo',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _DrawerTile(
                      color: const Color(0xFF87D2FF),
                      icon: Icons.history,
                      title: 'Historico',
                      subtitle: 'Mensagens salvas localmente',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HistoryScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _DrawerTile(
                      color: const Color(0xFF87D2FF),
                      icon: Icons.mark_email_read_outlined,
                      title: 'Carta',
                      subtitle: 'Gerar apresentacao em PDF',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CoverLetterScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _DrawerTile(
                      color: const Color(0xFFFFC7DE),
                      icon: Icons.travel_explore_rounded,
                      title: 'Buscar vagas',
                      subtitle: 'Pesquisar oportunidades e abrir links',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JobSearchScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _DrawerTile(
                      color: _yellow,
                      icon: Icons.badge_outlined,
                      title: 'Curriculo',
                      subtitle: 'Atualizar upload e embeddings',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const UserRegistrationScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (userId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(sessionProvider.notifier).clear();
                    ref.read(consentProvider.notifier).clear();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _paper,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sair'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppDrawer._ink, width: 3),
            boxShadow: const [
              BoxShadow(color: AppDrawer._ink, offset: Offset(6, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppDrawer._paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppDrawer._ink, width: 2),
                ),
                child: Icon(icon, color: AppDrawer._ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
