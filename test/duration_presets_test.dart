import 'package:apt_ev_charging/core/duration_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDurationMinutes', () {
    test('0분은 빈 문자열', () {
      expect(formatDurationMinutes(0), '');
    });
    test('음수는 0으로 취급', () {
      expect(formatDurationMinutes(-30), '');
    });
    test('시간 단위만 표시', () {
      expect(formatDurationMinutes(60), '1시간');
      expect(formatDurationMinutes(120), '2시간');
    });
    test('분 단위만 표시', () {
      expect(formatDurationMinutes(30), '30분');
      expect(formatDurationMinutes(45), '45분');
    });
    test('시간+분 혼합', () {
      expect(formatDurationMinutes(90), '1시간 30분');
      expect(formatDurationMinutes(150), '2시간 30분');
    });
  });

  group('parseDurationLabel', () {
    test('빈 문자열은 0', () {
      expect(parseDurationLabel(''), 0);
      expect(parseDurationLabel('   '), 0);
    });
    test('분 단위 파싱', () {
      expect(parseDurationLabel('30분'), 30);
    });
    test('시간 단위 파싱', () {
      expect(parseDurationLabel('2시간'), 120);
    });
    test('시간+분 파싱', () {
      expect(parseDurationLabel('1시간 30분'), 90);
      expect(parseDurationLabel('3시간 45분'), 225);
    });
    test('formatDurationMinutes 왕복', () {
      for (final m in [30, 60, 90, 120, 150, 180, 240]) {
        expect(parseDurationLabel(formatDurationMinutes(m)), m,
            reason: '$m 분 왕복');
      }
    });
  });

  group('durationPresets', () {
    test('선택하세요 + 28개 (30분 단위 14시간)', () {
      final list = durationPresets;
      expect(list.length, 29);
      expect(list.first.minutes, 0);
      expect(list.first.label, '선택하세요');
      expect(list.last.minutes, 840); // 14시간
      // 모든 충전기의 표준 시간이 실제 선택 항목에 있어야 한다.
      expect(list.map((preset) => preset.minutes),
          containsAll(chargerStandardMinutes.values.toSet()));
    });
  });

  group('formatDateTimeLocal / tryParseDateTimeLocal', () {
    test('datetime-local 형식 왕복', () {
      final dt = DateTime(2026, 4, 22, 14, 5);
      final s = formatDateTimeLocal(dt);
      expect(s, '2026-04-22T14:05');
      expect(tryParseDateTimeLocal(s), dt);
    });
    test('빈 문자열은 null', () {
      expect(tryParseDateTimeLocal(''), isNull);
    });
  });
}
