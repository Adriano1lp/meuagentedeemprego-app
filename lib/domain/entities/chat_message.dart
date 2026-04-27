// lib/domain/entities/chat_message.dart
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final String? pdfUrl;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.pdfUrl,
    required this.timestamp,
  });
}