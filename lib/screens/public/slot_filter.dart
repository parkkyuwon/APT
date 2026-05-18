import '../../models/app_state.dart';
import '../../models/parking_slot.dart';

/// 목록 화면 세그먼트 필터.
enum SlotFilter { all, occupied, available }

/// 단일 SlotDetail 이 필터에 해당하는지.
/// - all: 항상 true
/// - occupied: 점유됨
/// - available: 점유X 이면서 주차불가X (관리자 차단 슬롯 제외)
bool slotMatchesFilter(SlotDetail detail, SlotFilter filter) {
  switch (filter) {
    case SlotFilter.all:
      return true;
    case SlotFilter.occupied:
      return detail.isOccupied;
    case SlotFilter.available:
      return !detail.isOccupied && !detail.parkingBlocked;
  }
}

/// 한 충전타입 섹션의 슬롯 목록을 필터로 거른다.
/// detail 이 없는 슬롯은 빈 SlotDetail 로 간주(=사용가능).
List<ParkingSlot> filterSlots(
  List<ParkingSlot> slots,
  AppState state,
  SlotFilter filter,
) {
  return slots
      .where((s) => slotMatchesFilter(
            state.slotDetails[s.id] ?? const SlotDetail(),
            filter,
          ))
      .toList(growable: false);
}
