import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/models/indoor_positioning.dart';
import 'package:apt_ev_charging/services/fingerprint_positioner.dart';
import 'package:apt_ev_charging/services/beacon_observer.dart';
import 'package:apt_ev_charging/services/beacon_locator.dart';

void main() {
  final now = DateTime.utc(2026, 11, 23);
  List<BeaconObservation> signals(List<int> values, {DateTime? at}) => [
        for (var i = 0; i < values.length; i++)
          BeaconObservation(
              beaconId: 'b$i', rssi: values[i], observedAt: at ?? now),
      ];
  SurveySession sample(String id, String floor, double x, List<int> values,
          {bool excluded = false}) =>
      SurveySession(
          id: id,
          accountScope: 'a',
          floor: floor,
          xPct: x,
          yPct: 30,
          startedAt: now.subtract(const Duration(seconds: 15)),
          endedAt: now,
          observations: signals(values),
          excluded: excluded);

  test('percentage coordinates are explicit and invalid coordinates rejected',
      () {
    final s = sample('s', 'B1', .5, [-50, -60, -70]);
    expect(SurveySession.fromJson(s.toJson()).xPct, .5);
    expect(() => sample('s', 'B1', double.nan, [-50, -60, -70]),
        throwsArgumentError);
    expect(() => BeaconObservation(beaconId: 'b', rssi: 0, observedAt: now),
        throwsArgumentError);
  });
  test('fingerprint uses strongest matching vector and rejects stale signals',
      () {
    final sessions = [
      sample('s1', 'B1', 10, [-50, -60, -80]),
      sample('s2', 'B1', 80, [-80, -55, -50])
    ];
    const p = FingerprintPositioner();
    expect(p.estimate(sessions, signals([-50, -60, -80]), now: now)?.xPct, 10);
    expect(
        p.estimate(
            sessions,
            signals([-50, -60, -80],
                at: now.subtract(const Duration(seconds: 6))),
            now: now),
        isNull);
    expect(p.estimate(sessions, signals([-50, -60]), now: now), isNull);
  });
  test('ambiguous floors and distant identical corridors do not interpolate',
      () {
    const p = FingerprintPositioner();
    expect(
        p.estimate([
          sample('a', 'B1', 10, [-50, -60, -70]),
          sample('b', 'B2', 90, [-50, -60, -70])
        ], signals([-50, -60, -70]), now: now),
        isNull);
    final estimate = p.estimate([
      sample('a', 'B1', 10, [-50, -60, -70]),
      sample('b', 'B1', 90, [-50, -60, -70])
    ], signals([-50, -60, -70]), now: now)!;
    expect(estimate.xPct, 10);
    expect(estimate.quality, PositionQuality.low);
  });
  test('excluded, incomplete, wrong version and mixed accounts are not learned',
      () {
    const p = FingerprintPositioner();
    expect(
        p.estimate([
          sample('a', 'B1', 10, [-50, -60, -70], excluded: true)
        ], signals([-50, -60, -70]), now: now),
        isNull);
    expect(
        p.estimate([
          sample('a', 'B1', 10, [-50, -60, -70])
        ], signals([-50, -60, -70]), now: now, mapVersion: 'other'),
        isNull);
    final other = SurveySession(
        id: 'b',
        accountScope: 'other',
        floor: 'B1',
        xPct: 20,
        yPct: 20,
        startedAt: now,
        endedAt: now,
        observations: signals([-50, -60, -70]));
    expect(
        p.estimate([
          sample('a', 'B1', 10, [-50, -60, -70]),
          other
        ], signals([-50, -60, -70]), now: now),
        isNull);
  });
  test(
      'observer deduplicates original timestamps and ages packets without refresh',
      () {
    final observer = BeaconObserver(clock: () => now);
    observer.addObservations(signals([-50, -60, -70]));
    observer.addObservations(signals([-50, -60, -70]));
    expect(observer.observations.length, 3);
    expect(observer.recent(now.add(const Duration(seconds: 6))), isEmpty);
    observer.dispose();
  });
  test('iBeacon parser uses signed measured power and stable id', () {
    final parsed = parseIBeaconAdvertisement(
        [2, 21, ...List.filled(16, 0), 0, 1, 0, 2, 197],
        rssi: -65, observedAt: now)!;
    expect(parsed.beaconId, 'ib:00000000-0000-0000-0000-000000000000:1:2');
    expect(parsed.measuredPower, -59);
    expect(
        parseIBeaconAdvertisement([2, 21], rssi: -65, observedAt: now), isNull);
  });
  test(
      'reserved iBeacon power is unknown and parser preserves legacy uppercase IDs',
      () {
    final parsed = parseIBeaconAdvertisement(
        [2, 21, ...List.filled(16, 0xab), 0, 1, 0, 2, 128],
        rssi: -65, observedAt: now)!;
    expect(parsed.measuredPower, isNull);
    expect(parsed.beaconId, 'ib:ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB:1:2');
  });
  test(
      'fingerprints tolerate handset offset and median suppresses impulse outliers',
      () {
    final s = sample('s', 'B1', 10, [-50, -60, -80]);
    final observations = [
      ...signals([-44, -54, -74]),
      ...signals([-44, -54, -74]),
      ...signals([-10, -20, -30])
    ];
    final result =
        const FingerprintPositioner().estimate([s], observations, now: now)!;
    expect(result.xPct, 10);
    expect(result.score.isFinite, isTrue);
    expect(result.beaconCount, 3);
    expect(
        const FingerprintPositioner().estimate([s],
            signals([-50, -60, -80], at: now.add(const Duration(seconds: 1))),
            now: now),
        isNull);
    expect(
        const FingerprintPositioner().estimate(
            [s],
            signals([-50, -60, -80],
                at: now.subtract(const Duration(seconds: 5))),
            now: now),
        isNull);
  });
  test(
      'uncalibrated beacon inference returns region and rejects repeated points',
      () {
    final sessions = [
      for (var i = 0; i < 6; i++)
        sample('$i', 'B1', i * 15, [-50 - i, -60, -70])
    ];
    final candidate = const BeaconLocator().estimate('b0', sessions);
    expect(candidate, isNotNull);
    expect(candidate!.isMetric, isFalse);
    expect(candidate.confirmed, isFalse);
    expect(
        const BeaconLocator().estimate('b0', [
          for (var i = 0; i < 6; i++) sample('$i', 'B1', 20, [-50, -60, -70])
        ]),
        isNull);
  });
}
