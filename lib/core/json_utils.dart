/// 백엔드(특히 BIGSERIAL/NUMERIC)가 숫자를 문자열로 직렬화하는 경우를 흡수.
/// num? 직접 cast 는 String 입력 시 즉시 throw 하므로 모든 fromJson 에서
/// 이 헬퍼를 통해 정수/실수를 파싱하도록 통일한다.
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
