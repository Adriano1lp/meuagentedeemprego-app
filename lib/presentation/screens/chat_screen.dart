import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _ink = Color(0xFF111111);
  static const Color _canvas = Color(0xFFFFF6E9);
  static const Color _pink = Color(0xFFFF5D8F);
  static const Color _yellow = Color(0xFFFFE16A);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ProviderSubscription<ChatState>? _chatSubscription;

  @override
  void initState() {
    super.initState();

    _chatSubscription = ref.listenManual(chatProvider, (previous, next) {
      if ((previous?.messages.length ?? 0) != next.messages.length) {
        _scrollToBottom();
      }

      if (!mounted) return;

      final errorMessage = next.errorMessage;
      if (errorMessage != null && errorMessage.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(errorMessage)));
        ref.read(chatProvider.notifier).clearError();
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    final wasAccepted = await ref.read(chatProvider.notifier).sendMessage(text);
    if (wasAccepted) {
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analise da Vaga',
              style: theme.textTheme.titleLarge,
            ),
            Text(
              chatState.isLoading
                  ? 'Processando /processar'
                  : 'Cole a vaga e receba analise com PDF otimizado',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4E5566),
              ),
            ),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: _canvas),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: chatState.messages.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: chatState.messages.length,
                          itemBuilder: (context, index) {
                            return ChatBubble(
                              message: chatState.messages[index],
                            );
                          },
                        ),
                ),
              ),
            ),
            _buildInputArea(chatState.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: _brutalBoxDecoration(_yellow),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: _pillDecoration(_paper),
                  child: Text(
                    'Endpoint /processar',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Cole a descricao completa da vaga',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Esta tela envia o texto da oportunidade para a API, recebe a analise de aderencia e disponibiliza um PDF de curriculo otimizado como resposta.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _HeroTag(label: 'Resumo do fit'),
                    _HeroTag(label: 'Lacunas criticas'),
                    _HeroTag(label: 'PDF otimizado'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Modelo para testar',
            style: theme.textTheme.titleMedium?.copyWith(letterSpacing: -0.2),
          ),
          const SizedBox(height: 6),
          Text(
            'Use um dos modelos abaixo para preencher a entrada no formato esperado pelo endpoint.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF4E5566),
            ),
          ),
          const SizedBox(height: 12),
          _SuggestionCard(
            icon: Icons.dataset_linked_outlined,
            title: 'Analisar vaga',
            subtitle:
                'Preenche um pedido para analisar requisitos, aderencia, lacunas e palavras-chave ATS.',
            chipLabel: 'POST',
            onTap: () => _fillSuggestion(
              'Analise a vaga abaixo. Quero um resumo de aderencia, pontos fortes, lacunas criticas e recomendacoes praticas:\n\n[TEXTO DA VAGA AQUI]',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isLoading) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                isLoading
                    ? 'A API esta analisando a vaga e preparando a resposta.'
                    : 'Cole a vaga, toque em analisar e depois abra o PDF gerado na resposta.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF4E5566),
                    ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: _brutalBoxDecoration(
                _paper,
                radius: 18,
                offset: 6,
              ),
              child: TextField(
                controller: _messageController,
                enabled: !isLoading,
                minLines: 1,
                maxLines: 7,
                decoration: const InputDecoration(
                  hintText: 'Cole aqui a descricao completa da vaga para enviar ao /processar...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: isLoading ? _yellow : _pink,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _ink, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: _ink,
                    offset: Offset(4, 4),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: isLoading ? null : _handleSend,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: _ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_ink),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(
                  isLoading ? 'Analisando' : 'Analisar vaga',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fillSuggestion(String text) {
    _messageController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  BoxDecoration _brutalBoxDecoration(
    Color color, {
    double radius = 24,
    double offset = 8,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _ink, width: 3),
      boxShadow: [
        BoxShadow(
          color: _ink,
          offset: Offset(offset, offset),
        ),
      ],
    );
  }

  BoxDecoration _pillDecoration(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _ink, width: 2),
      boxShadow: const [
        BoxShadow(
          color: _ink,
          offset: Offset(3, 3),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String chipLabel;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chipLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardColorForTitle(title),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF111111), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF111111),
                  offset: Offset(6, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFDF7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF111111), width: 2),
                  ),
                  child: Icon(icon, color: const Color(0xFF111111)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDFDF7),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF111111),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              chipLabel,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF111111),
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF111111),
                              height: 1.35,
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

  Color _cardColorForTitle(String value) {
    return const Color(0xFFB6F36A);
  }
}

class _HeroTag extends StatelessWidget {
  final String label;

  const _HeroTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDF7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF111111), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF111111),
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF111111),
            ),
      ),
    );
  }
}
