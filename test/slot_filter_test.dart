import 'package:apt_ev_charging/models/app_state.dart';
import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/screens/public/slot_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 점유: vehicleNumber 있음 / 사용가능: 빈 detail / 주차불가: parkingBlocked
  const occupied = SlotDetail(vehicleNumber: '123가4567', startTime: '2026-05-18T00:00:00Z');
  const available = SlotDetail();
  const blocked = SlotDetail(parkingBlocked: true);

  group('slotMatchesFilter', () {
    test('all 은 모든 상태 통과', () {
      expect(slotMatchesFilter(occupied, SlotFilter.all), true);
      expect(slotMatchesFilter(available, SlotFilter.all), true);
      expect(slotMatchesFilter(blocked, SlotFilter.all), true);
    });

    test('occupied 는 점유된 것만', () {
      expect(slotMatchesFilter(occupied, SlotFilter.occupied), true);
      expect(slotMatchesFilter(available, SlotFilter.occupied), false);
      expect(slotMatchesFilter(blocked, SlotFilter.occupied), false);
    });

    test('available 은 점유X·주차불가X 만', () {
      expect(slotMatchesFilter(available, SlotFilter.available), true);
      expect(slotMatchesFilter(occupied, SlotFilter.available), false);
      expect(slotMatchesFilter(blocked, SlotFilter.available), false);
    });
  });

  group('filterSlots', () {
    final state = AppState.fromJson({
      'counts': {'fast50': 0, 'slow7': 0, 'slow3': 0},
      'slots': {
        'fast50': [
          {'id': 'fast50-1', 'typeId': 'fast50'},
          {'id': 'fast50-2', 'typeId': 'fast50'},
          {'id': 'fast50-3', 'typeId': 'fast50'},
        ],
      },
      'slotDetails': {
        'fast50-1': {'vehicleNumber': '123가4567', 'startTime': '2026-05-18T00:00:00Z'},
        'fast50-3': {'parkingBlocked': true},
      },
    });
    final slots = state.slots['fast50']!;

    test('all 은 3개 모두', () {
      expect(filterSlots(slots, state, SlotFilter.all).length, 3);
    });
    test('occupied 는 fast50-1 만', () {
      final r = filterSlots(slots, state, SlotFilter.occupied);
      expect(r.map((s) => s.id), ['fast50-1']);
    });
    test('available 은 fast50-2 만 (주차불가 fast50-3 제외)', () {
      final r = filterSlots(slots, state, SlotFilter.available);
      expect(r.map((s) => s.id), ['fast50-2']);
    });
  });
}
