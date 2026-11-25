import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/models/home_area.dart';
import 'package:apt_ev_charging/services/indoor_entry_notifications.dart';

void main() {
  test('notification is rejected after account or home setting changes', () {
    final area = HomeArea(
        accountScope: 'a',
        latitude: 37,
        longitude: 127,
        revision: 2,
        enabled: true);
    final entry = IndoorEntryNotification.parse({
      'type': 'indoorEntry',
      'siteId': 'home',
      'visitId': 'visit',
      'areaRevision': 2,
      'accountScope': 'a'
    });
    expect(entry!.matches(area), isTrue);
    expect(entry.matches(area.copyWith(revision: 3)), isFalse);
    expect(entry.matches(area.copyWith(enabled: false)), isFalse);
    expect(
        entry.matches(HomeArea(
            accountScope: 'b',
            latitude: 37,
            longitude: 127,
            revision: 2,
            enabled: true)),
        isFalse);
  });
  test('malformed or unrelated native notification is rejected', () {
    expect(IndoorEntryNotification.parse({'type': 'departure', 'visitId': 'x'}),
        isNull);
    expect(
        IndoorEntryNotification.parse({
          'type': 'indoorEntry',
          'siteId': 'home',
          'visitId': '',
          'areaRevision': 1,
          'accountScope': 'a'
        }),
        isNull);
  });
}
