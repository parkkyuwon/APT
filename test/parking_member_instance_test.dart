import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parking edits preserve the server account instance marker', () {
    final detail = SlotDetail.fromJson({
      'ownerEmail': 'member@example.invalid',
      'ownerInstanceAt': '2026-10-14T01:02:03Z',
      'vehicleNumber': '12가3456',
    });
    final edited = detail.copyWith(contact: '010-0000-0000');
    expect(edited.toJson()['ownerInstanceAt'], '2026-10-14T01:02:03Z');
    expect(const SlotDetail().toJson(), isNot(contains('ownerInstanceAt')));
  });
}
