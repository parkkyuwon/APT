import '../core/errors.dart';
import '../core/json_utils.dart';

/// profile 응답 (GET /api/profile) + users 목록 응답 공통 사용.
class AppUser {
  AppUser({
    required this.email,
    required this.name,
    required this.nickname,
    required this.picture,
    required this.status,
    required this.role,
    required this.vehicleNumber,
    required this.phoneNumber,
    required this.profileComplete,
    required this.vehicleVerified,
    this.createdAt,
    this.approvedAt,
    this.approvedBy = '',
    this.withdrawnAt,
    this.consentAt,
    this.vehiclePhoto = '',
  });

  final String email;
  final String name;
  final String nickname;
  final String picture;
  final AuthStatus status;
  final String role;
  final String vehicleNumber;
  final String phoneNumber;
  final bool profileComplete;
  final bool vehicleVerified;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String approvedBy;
  final DateTime? withdrawnAt;
  final DateTime? consentAt;
  final String vehiclePhoto; // data:image/... base64 (관리자 전용 view 응답)

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final role = asStr(json['role']);
    return AppUser(
      email: asStr(json['email']),
      name: asStr(json['name']),
      nickname: asStr(json['nickname']),
      picture: asStr(json['picture']),
      status: authStatusFromString(asStrOrNull(json['status'])),
      role: role.isEmpty ? 'user' : role,
      vehicleNumber: firstStr(json, 'vehicleNumber', 'vehicle_number'),
      phoneNumber: firstStr(json, 'phoneNumber', 'phone_number'),
      profileComplete: asBool(json['profileComplete']),
      vehicleVerified: asBool(json['vehicle_verified']) || asBool(json['vehicleVerified']),
      createdAt: asDateTimeOrNull(json['createdAt'] ?? json['created_at']),
      approvedAt: asDateTimeOrNull(json['approvedAt'] ?? json['approved_at']),
      approvedBy: firstStr(json, 'approvedBy', 'approved_by'),
      withdrawnAt: asDateTimeOrNull(json['withdrawn_at'] ?? json['withdrawnAt']),
      consentAt: asDateTimeOrNull(json['consent_at'] ?? json['consentAt']),
      vehiclePhoto: firstStr(json, 'vehiclePhoto', 'vehicle_photo'),
    );
  }
}
