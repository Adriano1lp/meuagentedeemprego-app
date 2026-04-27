import 'package:flutter/material.dart';

import '../../domain/entities/chat_message.dart';
import '../utils/authenticated_pdf_opener.dart';

class ChatBubble extends StatelessWidget {
  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _pink = Color(0xFFFF5D8F);
  static const Color _blue = Color(0xFF87D2FF);
  static const Color _green = Color(0xFFB6F36A);

  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final pdfUri = _buildPdfUri(message.pdfUrl);
    final theme = Theme.of(context);
    final bubbleColor = isUser ? _pink : _paper;
    final textColor = _ink;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isUser ? 22 : 8),
            bottomRight: Radius.circular(isUser ? 8 : 22),
          ),
          boxShadow: const [
            BoxShadow(
              color: _ink,
              offset: Offset(5, 5),
            ),
          ],
          border: Border.all(color: _ink, width: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUser ? _paper : (pdfUri != null ? _green : _blue),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _ink, width: 2),
                  ),
                  child: Text(
                    isUser ? 'VOCE' : 'AGENTE',
                    style: theme.textTheme.bodySmall?.copyWith(color: _ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: textColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatTimestamp(message.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4E5566),
              ),
            ),
            if (pdfUri != null) ...[
              const SizedBox(height: 10),
              const Divider(color: _ink, height: 1),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _openPdf(context, pdfUri),
                style: TextButton.styleFrom(
                  foregroundColor: _ink,
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Abrir PDF'),
              ),
            ],
          ],
        ),
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
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
