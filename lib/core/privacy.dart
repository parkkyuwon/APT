import '../models/session.dart';

/// 비등록 사용자(NFC/QR 게스트 자동 등록) 표시 라벨. 백엔드 guest-park 와 일치.
const String kGuestVehicleLabel = '비등록 사용자';

/// 전화번호 가운데 자리 마스킹.
/// 010-1234-5678 → 010-****-5678.
String maskPhone(String raw) {
  if (raw.trim().isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8) return '***-****-****';
  final first3 = digits.substring(0, 3);
  final last4 = digits.substring(digits.length - 4);
  return '$first3-****-$last4';
}

/// 차량번호 뒷자리 4자리 중 앞 2자리 마스킹.
/// 123가4567 → 123가**67.
String maskVehicle(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  if (s.length < 4) return '****';
  final last2 = s.substring(s.length - 2);
  final head = s.substring(0, s.length - 4);
  return '$head**$last2';
}

/// 관리자면 원본, 아니면 전화번호 마스킹.
String phoneFor(SessionInfo? me, String raw) =>
    (me?.isAdmin ?? false) ? raw : maskPhone(raw);

/// 관리자면 원본, 아니면 차량번호 마스킹.
/// 게스트 라벨("비등록 사용자")은 실제 PII 가 아니므로 마스킹 안 함.
String vehicleFor(SessionInfo? me, String raw) {
  if (raw == kGuestVehicleLabel) return raw;
  return (me?.isAdmin ?? false) ? raw : maskVehicle(raw);
}
