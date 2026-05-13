import 'package:apt_ev_charging/models/app_state.dart';
import 'package:apt_ev_charging/models/charger_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppState.empty', () {
    test('기본 counts가 chargerTypes.defaultCount 합계', () {
      final s = AppState.empty();
      expect(s.counts['fast50'], 3);
      expect(s.counts['slow7'], 11);
      expect(s.counts['slow3'], 14);
      expect(s.totalSlots(), 28);
      expect(s.occupiedSlots(), 0);
    });
    test('유지보수 모드 기본값 false', () {
      final s = AppState.empty();
      expect(s.maintenanceMode, false);
      expect(s.adEnabled, true);
      expect(s.popupNotice.enabled, false);
    });
  });

  group('AppState.fromJson', () {
    test('빈 slots 입력시 counts 기반 자동 생성', () {
      final s = AppState.fromJson({
        'counts': {'fast50': 1, 'slow7': 2, 'slow3': 0},
        'slots': {},
      });
      expect(s.slots['fast50']?.length, 1);
      expect(s.slots['slow7']?.length, 2);
      expect(s.slots['slow3']?.length, 0);
      expect(s.totalSlots(), 3);
    });
    test('slotDetails occupied 카운팅', () {
      final s = AppState.fromJson({
        'counts': {'fast50': 2, 'slow7': 0, 'slow3': 0},
        'slotDetails': {
          'fast50-1': {
            'vehicleNumber': '123가 4567',
            'ownerEmail': 'a@b.com',
          },
          'fast50-2': {},
        },
      });
      expect(s.occupiedSlots(), 1);
    });
    test('slotMapPositions 파싱', () {
      final s = AppState.fromJson({
        'slotMapPositions': {
          'fast50-1': {'x': 0.3, 'y': 0.7},
        },
      });
      expect(s.slotMapPositions['fast50-1']?.x, 0.3);
      expect(s.slotMapPositions['fast50-1']?.y, 0.7);
    });
  });

  group('chargerTypeById', () {
    test('known id', () {
      expect(chargerTypeById('fast50')?.name, '50kW 급속');
      expect(chargerTypeById('slow7')?.name, '7kW 완속');
      expect(chargerTypeById('slow3')?.name, '3kW 완속');
    });
    test('unknown id → null', () {
      expect(chargerTypeById('unknown'), isNull);
    });
  });
}
