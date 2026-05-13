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
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    String pick(String camel, String snake) =>
        (json[camel] as String?) ?? (json[snake] as String?) ?? '';

    return ChatMessage(
      id: asInt(json['id']),
      authorEmail: pick('authorEmail', 'author_email'),
      authorNickname: pick('authorNickname', 'author_nickname'),
      authorRole: pick('authorRole', 'author_role'),
      message: (json['message'] as String?) ?? '',
      createdAt: parse(json['createdAt'] ?? json['created_at']),
      editedAt: parse(json['editedAt'] ?? json['edited_at']),
    );
  }
}
