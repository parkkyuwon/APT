import '../core/errors.dart';

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
    DateTime? parse(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isEmpty) return null;
      return DateTime.tryParse(value.toString());
    }

    // 서버는 snake_case/camelCase 를 혼용한다 ([profile.js], [users.js] 참고).
    String first(String camel, String snake) =>
        (json[camel] as String?) ?? (json[snake] as String?) ?? '';

    return AppUser(
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      nickname: (json['nickname'] as String?) ?? '',
      picture: (json['picture'] as String?) ?? '',
      status: authStatusFromString(json['status'] as String?),
      role: (json['role'] as String?) ?? 'user',
      vehicleNumber: first('vehicleNumber', 'vehicle_number'),
      phoneNumber: first('phoneNumber', 'phone_number'),
      profileComplete: json['profileComplete'] == true,
      vehicleVerified: json['vehicle_verified'] == true || json['vehicleVerified'] == true,
      createdAt: parse(json['createdAt'] ?? json['created_at']),
      approvedAt: parse(json['approvedAt'] ?? json['approved_at']),
      approvedBy: first('approvedBy', 'approved_by'),
      withdrawnAt: parse(json['withdrawn_at'] ?? json['withdrawnAt']),
      consentAt: parse(json['consent_at'] ?? json['consentAt']),
      vehiclePhoto: first('vehiclePhoto', 'vehicle_photo'),
    );
  }
}
