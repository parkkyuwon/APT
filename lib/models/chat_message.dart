import '../core/json_utils.dart';

/// /api/chat 메시지.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.authorEmail,
    required this.authorNickname,
    required this.authorRole,
    required this.message,
    required this.createdAt,
    this.editedAt,
  });

  final int id;
  final String authorEmail;
  final String authorNickname;
  final String authorRole;
  final String message;
  final DateTime? createdAt;
  final DateTime? editedAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: asInt(json['id']),
      authorEmail: firstStr(json, 'authorEmail', 'author_email'),
      authorNickname: firstStr(json, 'authorNickname', 'author_nickname'),
      authorRole: firstStr(json, 'authorRole', 'author_role'),
      message: asStr(json['message']),
      createdAt: asDateTimeOrNull(json['createdAt'] ?? json['created_at']),
      editedAt: asDateTimeOrNull(json['editedAt'] ?? json['edited_at']),
    );
  }
}
