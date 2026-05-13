/// API 응답에 포함되는 인증 상태 플래그.
///
/// [auth.js serializeSession] 및 관련 핸들러가 반환하는 값과 일치한다.
enum AuthStatus { pending, approved, rejected, blocked, withdrawn, dormant, unknown }

AuthStatus authStatusFromString(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'pending':
      return AuthStatus.pending;
    case 'approved':
      return AuthStatus.approved;
    case 'rejected':
      return AuthStatus.rejected;
    case 'blocked':
      return AuthStatus.blocked;
    case 'withdrawn':
      return AuthStatus.withdrawn;
    case 'dormant':
      return AuthStatus.dormant;
    default:
      return AuthStatus.unknown;
  }
}

String authStatusToString(AuthStatus status) {
  switch (status) {
    case AuthStatus.pending:
      return 'pending';
    case AuthStatus.approved:
      return 'approved';
    case AuthStatus.rejected:
      return 'rejected';
    case AuthStatus.blocked:
      return 'blocked';
    case AuthStatus.withdrawn:
      return 'withdrawn';
    case AuthStatus.dormant:
      return 'dormant';
    case AuthStatus.unknown:
      return 'unknown';
  }
}

/// 서버가 반환한 { ok: false, error: ... } 를 표현.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.authStatus,
    this.needsConsent = false,
    this.needsProfileSetup = false,
    this.needsPhotoVerification = false,
    this.missing = const <String>[],
    this.rawBody,
  });

  final int statusCode;
  final String message;
  final AuthStatus? authStatus;
  final bool needsConsent;
  final bool needsProfileSetup;
  final bool needsPhotoVerification;
  final List<String> missing;
  final Map<String, dynamic>? rawBody;

  bool get isAuthRequired => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 네트워크 레벨 오류 (타임아웃, DNS, 연결 끊김 등).
class NetworkException implements Exception {
  NetworkException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'NetworkException: $message';
}
