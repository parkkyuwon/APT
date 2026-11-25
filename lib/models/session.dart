import '../core/errors.dart';
import '../core/json_utils.dart';

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
    required this.profileComplete,
    this.needsConsent = false,
    this.vehicleVerificationRequired = true,
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
  final bool profileComplete;
  final bool needsConsent;
  final bool vehicleVerificationRequired;

  bool get isAdmin => role == 'admin' && approved;

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    final role = asStr(json['role']);
    return SessionInfo(
      email: asStr(json['email']),
      name: asStr(json['name']),
      nickname: asStr(json['nickname']),
      picture: asStr(json['picture']),
      role: role.isEmpty ? 'user' : role,
      status: authStatusFromString(asStrOrNull(json['status'])),
      approved: asBool(json['approved']),
      authType: asStr(json['authType']),
      vehicleNumber: asStr(json['vehicleNumber']),
      profileComplete: asBool(json['profileComplete']),
      needsConsent: asBool(json['needsConsent']),
      vehicleVerificationRequired: json['vehicleVerificationRequired'] != false,
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
        'profileComplete': profileComplete,
        'needsConsent': needsConsent,
        'vehicleVerificationRequired': vehicleVerificationRequired,
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
    final rawSession = asMapOrNull(json['session']);
    final needsConsent =
        asBool(json['needsConsent'] ?? rawSession?['needsConsent']);
    return AuthBootstrap(
      googleEnabled: asBool(json['googleEnabled']),
      googleClientId: asStrOrNull(json['googleClientId']),
      session: rawSession == null
          ? null
          : SessionInfo.fromJson({
              ...rawSession,
              'needsConsent': needsConsent,
              'vehicleVerificationRequired':
                  json['vehicleVerificationRequired'] ??
                      rawSession['vehicleVerificationRequired'],
            }),
      needsConsent: needsConsent,
      needsPhotoVerification: asBool(json['needsPhotoVerification']),
      pendingUsers: asListOfMaps(json['users']),
    );
  }
}
