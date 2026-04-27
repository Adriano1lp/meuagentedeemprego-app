import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/chat_message.dart';
import '../providers/chat_provider.dart';
import '../utils/authenticated_pdf_opener.dart';
import '../widgets/app_drawer.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static const Color _canvas = Color(0xFFFFF6E9);
  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _yellow = Color(0xFFFFE16A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref
        .watch(chatProvider)
        .messages
        .where((message) => !message.isUser)
        .toList()
        .reversed
        .toList();
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Historico')),
      body: DecoratedBox(
        decoration: const BoxDecoration(color: _canvas),
        child: history.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    width: 420,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _yellow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _ink, width: 3),
                      boxShadow: const [
                        BoxShadow(color: _ink, offset: Offset(8, 8)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history_toggle_off,
                          size: 72,
                          color: _ink,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum retorno salvo ainda.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Quando o assistente responder, o resumo e o PDF aparecerao aqui.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4E5566),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  return _HistoryResponseCard(message: history[index]);
                },
              ),
      ),
    );
  }
}

class _HistoryResponseCard extends StatefulWidget {
  final ChatMessage message;

  const _HistoryResponseCard({required this.message});

  @override
  State<_HistoryResponseCard> createState() => _HistoryResponseCardState();
}

class _HistoryResponseCardState extends State<_HistoryResponseCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pdfUri = _buildPdfUri(widget.message.pdfUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: HistoryScreen._paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HistoryScreen._ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: HistoryScreen._ink,
            offset: Offset(6, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: HistoryScreen._yellow,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: HistoryScreen._ink, width: 2),
                      ),
                      child: Text(
                        'Retorno IA',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: HistoryScreen._ink,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimestamp(widget.message.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4E5566),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Text(
                    widget.message.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HistoryScreen._ink,
                      height: 1.45,
                    ),
                  ),
                  secondChild: Text(
                    widget.message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HistoryScreen._ink,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (pdfUri != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openPdf(context, pdfUri),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF87D2FF),
                            foregroundColor: HistoryScreen._ink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Abrir PDF'),
                        ),
                      ),
                    if (pdfUri != null) const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5D8F),
                          foregroundColor: HistoryScreen._ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: Icon(
                          _isExpanded
                              ? Icons.unfold_less_rounded
                              : Icons.unfold_more_rounded,
                        ),
                        label: Text(_isExpanded ? 'Recolher' : 'Expandir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Uri? _buildPdfUri(String? pdfUrl) {
    if (pdfUrl == null || pdfUrl.trim().isEmpty) return null;

    final uri = Uri.tryParse(pdfUrl.trim());
    if (uri == null) return null;
    if (!uri.hasScheme && !uri.isAbsolute) return null;

    return uri;
  }

  Future<void> _openPdf(BuildContext context, Uri uri) async {
    await AuthenticatedPdfOpener.open(context, uri);
  }

  String _formatTimestamp(DateTime timestamp) {
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}
