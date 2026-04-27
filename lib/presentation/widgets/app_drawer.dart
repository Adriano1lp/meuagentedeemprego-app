import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/chat_repository_impl.dart';
import '../providers/session_provider.dart';
import '../screens/chat_screen.dart';
import '../screens/history_screen.dart';
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
    final userId = ref.watch(sessionProvider).userId;

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
                        'Usuario: $userId',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: _ink),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
              child: _DrawerTile(
                color: _green,
                icon: Icons.home_rounded,
                title: 'Home',
                subtitle: 'Voltar para a tela principal',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const ChatScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _DrawerTile(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: _DrawerTile(
                color: _yellow,
                icon: Icons.badge_outlined,
                title: 'Cadastro',
                subtitle: 'Atualizar usuario e reenviar curriculo',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserRegistrationScreen(),
                    ),
                  );
                },
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _yellow,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _ink, width: 3),
                  boxShadow: const [
                    BoxShadow(color: _ink, offset: Offset(6, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API atual',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ChatRepositoryImpl.apiBaseUrl,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (userId != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await ref.read(sessionProvider.notifier).clear();
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const UserRegistrationScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _paper,
                        ),
                        child: const Text('Trocar usuario'),
                      ),
                    ],
                  ],
                ),
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
