import '../core/errors.dart';

/// [auth.js serializeSession] 및 session-admin/session-public 응답 형태.
class SessionInfo {
  SessionInfo({
    required this.email,
    required this.name,
    required this.nickname,
    required this.picture,
    required this.role,
    required this.status,
    required this.approved,
    required this.authType,
    required this.vehicleNumber,
    required this.phoneNumber,
    required this.profileComplete,
  });

  final String email;
  final String name;
  final String nickname;
  final String picture;
  final String role;
  final AuthStatus status;
  final bool approved;
  final String authType;
  final String vehicleNumber;
  final String phoneNumber;
  final bool profileComplete;

  bool get isAdmin => role == 'admin' && approved;

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      nickname: (json['nickname'] as String?) ?? '',
      picture: (json['picture'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'user',
      status: authStatusFromString(json['status'] as String?),
      approved: json['approved'] == true,
      authType: (json['authType'] as String?) ?? '',
      vehicleNumber: (json['vehicleNumber'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      profileComplete: json['profileComplete'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'name': name,
        'nickname': nickname,
        'picture': picture,
        'role': role,
        'status': authStatusToString(status),
        'approved': approved,
        'authType': authType,
        'vehicleNumber': vehicleNumber,
        'phoneNumber': phoneNumber,
        'profileComplete': profileComplete,
      };
}

/// /api/auth, /api/session-public, /api/session-admin 응답 래퍼.
class AuthBootstrap {
  AuthBootstrap({
    required this.googleEnabled,
    required this.googleClientId,
    required this.session,
    required this.needsConsent,
    required this.needsPhotoVerification,
    required this.pendingUsers,
  });

  final bool googleEnabled;
  final String? googleClientId;
  final SessionInfo? session;
  final bool needsConsent;
  final bool needsPhotoVerification;
  final List<Map<String, dynamic>> pendingUsers;

  factory AuthBootstrap.fromJson(Map<String, dynamic> json) {
    final raw = json['session'];
    return AuthBootstrap(
      googleEnabled: json['googleEnabled'] == true,
      googleClientId: json['googleClientId'] as String?,
      session: raw is Map<String, dynamic> ? SessionInfo.fromJson(raw) : null,
      needsConsent: json['needsConsent'] == true,
      needsPhotoVerification: json['needsPhotoVerification'] == true,
      pendingUsers: (json['users'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
    );
  }
}
