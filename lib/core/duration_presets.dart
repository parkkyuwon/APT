/// [script.js DURATION_PRESETS] 포팅 — 30분 단위로 14시간까지.
class DurationPreset {
  const DurationPreset({required this.minutes, required this.label});
  final int minutes;
  final String label;
}

List<DurationPreset> get durationPresets {
  final list = <DurationPreset>[
    const DurationPreset(minutes: 0, label: '선택하세요'),
  ];
  for (var i = 1; i <= 28; i++) {
    final m = i * 30;
    list.add(DurationPreset(minutes: m, label: formatDurationMinutes(m)));
  }
  return list;
}

/// 충전기 종류별 표준 충전 소요시간(분).
/// 50kW 급속 = 2시간, 7kW/3kW 완속 = 14시간.
const Map<String, int> chargerStandardMinutes = {
  'fast50': 120,
  'slow7': 840,
  'slow3': 840,
};

int defaultDurationMinutesFor(String typeId) =>
    chargerStandardMinutes[typeId] ?? 60;

/// "1시간 30분", "30분" 등 라벨 생성.
String formatDurationMinutes(int minutes) {
  final n = minutes < 0 ? 0 : minutes;
  if (n == 0) return '';
  final hours = n ~/ 60;
  final remain = n % 60;
  if (hours == 0) return '$remain분';
  if (remain == 0) return '$hours시간';
  return '$hours시간 $remain분';
}

/// "1시간 30분" → 90 분. 파싱 실패 시 0.
int parseDurationLabel(String label) {
  final s = label.trim();
  if (s.isEmpty) return 0;
  final hourMatch = RegExp(r'(\d+)\s*시간').firstMatch(s);
  final minMatch = RegExp(r'(\d+)\s*분').firstMatch(s);
  final h = hourMatch != null ? int.parse(hourMatch.group(1)!) : 0;
  final m = minMatch != null ? int.parse(minMatch.group(1)!) : 0;
  return h * 60 + m;
}

/// ISO-8601 "YYYY-MM-DDTHH:MM" 형식. datetime-local input 호환.
String formatDateTimeLocal(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  return '$y-$mo-${d}T$h:$mi';
}

DateTime? tryParseDateTimeLocal(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return DateTime.tryParse(t);
}
