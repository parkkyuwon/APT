import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy parking records reject voice by default', () {
    final detail = SlotDetail.fromJson({'vehicleNumber': '123가4567'});
    expect(detail.parkingRegistrationId, '');
    expect(detail.callAllowed, isFalse);
  });
  test('server voice identity and owner choice survive copy and cache JSON',
      () {
    final detail = SlotDetail.fromJson({
      'parkingRegistrationId': 'opaque-1',
      'callAllowed': true,
      'vehicleNumber': '123가4567'
    });
    final restored =
        SlotDetail.fromJson(detail.copyWith(parkingBlocked: true).toJson());
    expect(restored.parkingRegistrationId, 'opaque-1');
    expect(restored.callAllowed, isTrue);
  });
}
