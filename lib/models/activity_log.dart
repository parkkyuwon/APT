import '../core/json_utils.dart';

/// /api/logs 활동 로그 (관리자 전용).
class ActivityLog {
  ActivityLog({
    required this.id,
    required this.actorEmail,
    required this.actorNickname,
    required this.actorRole,
    required this.action,
    required this.actionTarget,
    required this.details,
    required this.createdAt,
    this.ip = '',
    this.userAgent = '',
  });

  final int id;
  final String actorEmail;
  final String actorNickname;
  final String actorRole;
  final String action;
  final String actionTarget;
  final Map<String, dynamic> details;
  final DateTime? createdAt;
  final String ip;
  final String userAgent;

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    String s(String camel, String snake) =>
        (json[camel] as String?) ?? (json[snake] as String?) ?? '';
    final rawDetails = json['details'];
    return ActivityLog(
      id: asInt(json['id']),
      actorEmail: s('actorEmail', 'actor_email'),
      actorNickname: s('actorNickname', 'actor_nickname'),
      actorRole: s('actorRole', 'actor_role'),
      action: (json['action'] as String?) ?? '',
      actionTarget: s('actionTarget', 'action_target'),
      details: rawDetails is Map
          ? Map<String, dynamic>.from(rawDetails)
          : const <String, dynamic>{},
      createdAt: DateTime.tryParse(
        (json['createdAt'] ?? json['created_at'])?.toString() ?? '',
      ),
      ip: s('ip', 'ip_address'),
      userAgent: s('userAgent', 'user_agent'),
    );
  }
}
