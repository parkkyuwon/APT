import 'dart:math' as math;
import '../models/indoor_positioning.dart';
import 'fingerprint_positioner.dart';

/// Estimates only a strong-signal region on an uncalibrated diagram.
/// A site survey must confirm the beacon before writing its installed location.
class BeaconLocator {
  const BeaconLocator();
  BeaconEstimate? estimate(String beaconId, List<SurveySession> sessions,
      {String siteId = 'home', String mapVersion = 'simplified-v1'}) {
    final usable = sessions
        .where(
            (s) => s.usable && s.siteId == siteId && s.mapVersion == mapVersion)
        .toList();
    if (usable.map((s) => s.accountScope).toSet().length != 1) return null;
    // Aggregate repeated visits at one coordinate before counting spatial evidence.
    final grouped = <String, List<SurveySession>>{};
    for (final s in usable) {
      if (s.observations.any((o) => o.beaconId == beaconId)) {
        grouped.putIfAbsent('${s.floor}:${s.xPct}:${s.yPct}', () => []).add(s);
      }
    }
    final points = grouped.values
        .map((list) => (
              session: list.first,
              rssi: signalMedian(list.expand((s) => s.observations
                  .where((o) => o.beaconId == beaconId)
                  .map((o) => o.rssi)))
            ))
        .toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    if (points.length < 3) return null;
    final best = points.first;
    if (points.any((p) =>
        p.session.floor != best.session.floor && best.rssi - p.rssi < 6)) {
      return null;
    }
    final floorPoints =
        points.where((p) => p.session.floor == best.session.floor).toList();
    if (floorPoints.length < 3) return null;
    final strong = floorPoints.where((p) => best.rssi - p.rssi <= 12).toList();
    var x = 0.0, y = 0.0, total = 0.0;
    for (final p in strong) {
      final w = math.pow(10, (p.rssi - best.rssi) / 20).toDouble();
      total += w;
      x += p.session.xPct * w;
      y += p.session.yPct * w;
    }
    x /= total;
    y /= total;
    var spread = 0.0;
    for (final p in strong) {
      spread = math.max(
          spread,
          math.sqrt(math.pow(p.session.xPct - x, 2) +
              math.pow(p.session.yPct - y, 2)));
    }
    return BeaconEstimate(
        beaconId: beaconId,
        floor: best.session.floor,
        mapVersion: mapVersion,
        xPct: x,
        yPct: y,
        spreadPct: math.max(5, spread),
        pointCount: floorPoints.length);
  }
}
