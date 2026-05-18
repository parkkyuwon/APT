/// 백엔드 응답에 예상치 못한 타입이 와도 type cast 예외가 발생하지 않도록
/// 안전하게 변환해주는 헬퍼들.
///
/// - 숫자: BIGSERIAL/NUMERIC 등 문자열 직렬화 흡수
/// - 문자열: 객체/숫자/널이 와도 빈 문자열로 폴백
/// - 서버 `error` 객체: 사람이 읽을 수 있는 메시지로 평탄화
///
/// 백엔드(profile.js, auth.js, users.js 등)는 시기·필드에 따라 같은 키를
/// 문자열 또는 객체로 반환하기도 한다. `value as String?` 같은 직접 캐스팅은
/// `_Map<String, dynamic>' is not a subtype of type 'String?'` 으로 터지므로
/// 모든 fromJson 에서 이 헬퍼를 통해 파싱한다.
library;

int asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? fallback;
  return fallback;
}

double asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

/// dynamic 값을 안전하게 String 으로 변환. 변환 불가 시 빈 문자열.
/// (객체/Map/List 가 와도 throw 하지 않음)
String asStr(dynamic value) {
  if (value is String) return value;
  if (value == null) return '';
  if (value is num || value is bool) return value.toString();
  return '';
}

/// dynamic 값을 안전하게 String? 으로 변환. 문자열이 아니면 null.
String? asStrOrNull(dynamic value) => value is String ? value : null;

/// dynamic 값을 안전하게 bool 로 변환. 변환 불가 시 false.
/// 'true'/'1' 문자열도 true 로 인정.
bool asBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) return value == 'true' || value == '1';
  if (value is num) return value != 0;
  return false;
}

/// dynamic 값을 안전하게 DateTime? 으로 변환. 빈 문자열/널/파싱 실패 시 null.
DateTime? asDateTimeOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isEmpty) return null;
  return DateTime.tryParse(value.toString());
}

/// dynamic 값을 안전하게 List<T> 으로 변환. 타입에 맞지 않는 요소는 제거.
List<T> asListOf<T>(dynamic value) {
  if (value is List) return value.whereType<T>().toList();
  return const [];
}

/// dynamic 값을 안전하게 List<Map<String, dynamic>> 으로 변환.
List<Map<String, dynamic>> asListOfMaps(dynamic value) {
  if (value is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final item in value) {
    if (item is Map) {
      out.add(Map<String, dynamic>.from(item));
    }
  }
  return out;
}

/// dynamic 값을 안전하게 Map<String, dynamic>? 으로 변환. Map 이 아니면 null.
Map<String, dynamic>? asMapOrNull(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// JSON 응답에서 camelCase 와 snake_case 중 먼저 발견된 문자열 값을 반환.
/// 둘 다 없거나 문자열이 아니면 빈 문자열.
String firstStr(Map<String, dynamic> json, String camel, String snake) {
  final c = json[camel];
  if (c is String && c.isNotEmpty) return c;
  final s = json[snake];
  if (s is String && s.isNotEmpty) return s;
  return '';
}

/// 서버의 `error` 필드를 안전하게 사람이 읽을 수 있는 메시지로 변환.
/// - String: 그대로
/// - Map: {message,msg,error,detail,description} 키 또는 `fields` 합본
/// - 기타: toString()
String? stringifyError(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Map) {
    for (final k in const ['message', 'msg', 'error', 'detail', 'description']) {
      final v = value[k];
      if (v is String && v.isNotEmpty) return v;
    }
    final fields = value['fields'];
    if (fields is Map) {
      final parts = <String>[];
      fields.forEach((_, v) {
        if (v is String && v.isNotEmpty) parts.add(v);
      });
      if (parts.isNotEmpty) return parts.join('\n');
    }
    return value.toString();
  }
  return value.toString();
}
