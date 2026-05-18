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
    return ActivityLog(
      id: asInt(json['id']),
      actorEmail: firstStr(json, 'actorEmail', 'actor_email'),
      actorNickname: firstStr(json, 'actorNickname', 'actor_nickname'),
      actorRole: firstStr(json, 'actorRole', 'actor_role'),
      action: asStr(json['action']),
      actionTarget: firstStr(json, 'actionTarget', 'action_target'),
      details: asMapOrNull(json['details']) ?? const <String, dynamic>{},
      createdAt: asDateTimeOrNull(json['createdAt'] ?? json['created_at']),
      ip: firstStr(json, 'ip', 'ip_address'),
      userAgent: firstStr(json, 'userAgent', 'user_agent'),
    );
  }
}
