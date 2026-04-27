import 'package:hive/hive.dart';

import '../../domain/entities/chat_message.dart';

part 'message_model.g.dart';

@HiveType(typeId: 0)
class MessageModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String text;

  @HiveField(2)
  late bool isUser;

  @HiveField(3)
  late String? pdfUrl;

  @HiveField(4)
  late DateTime timestamp;

  static MessageModel fromEntity(ChatMessage e) => MessageModel()
    ..id = e.id
    ..text = e.text
    ..isUser = e.isUser
    ..pdfUrl = e.pdfUrl
    ..timestamp = e.timestamp;

  ChatMessage toEntity() => ChatMessage(
    id: id,
    text: text,
    isUser: isUser,
    pdfUrl: pdfUrl,
    timestamp: timestamp,
  );
}
