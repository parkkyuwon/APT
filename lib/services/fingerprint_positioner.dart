import 'dart:math' as math;
import '../models/indoor_positioning.dart';

double signalMedian(Iterable<num> values) {
  final sorted = values.map((v) => v.toDouble()).toList()..sort();
  if (sorted.isEmpty) return double.nan;
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

Map<String, double> signalVector(Iterable<BeaconObservation> observations) {
  final groups = <String, List<int>>{};
  for (final o in observations) {
    groups.putIfAbsent(o.beaconId, () => []).add(o.rssi);
  }
  return groups.map((key, value) => MapEntry(key, signalMedian(value)));
}

class FingerprintPositioner {
  const FingerprintPositioner();
  PositionEstimate? estimate(
      List<SurveySession> sessions, List<BeaconObservation> observations,
      {required DateTime now,
      String siteId = 'home',
      String mapVersion = 'simplified-v1',
      String? floor}) {
    final usable = sessions
        .where(
            (s) => s.usable && s.siteId == siteId && s.mapVersion == mapVersion)
        .toList();
    if (usable.map((s) => s.accountScope).toSet().length != 1) return null;
    final fresh = observations
        .where((o) =>
            !o.observedAt.isAfter(now) &&
            now.difference(o.observedAt) < const Duration(seconds: 5))
        .toList();
    final live = signalVector(fresh);
    if (live.length < 3) return null;
    final candidates = <_Match>[];
    for (final session in usable) {
      if (floor != null && session.floor != floor) continue;
      final vector = signalVector(session.observations);
      final common = live.keys.where(vector.containsKey).toList();
      if (common.length < 3) continue;
      final residuals = common.map((id) => live[id]! - vector[id]!).toList();
      // A bounded device offset reduces handset bias while retaining absolute evidence.
      final offset = signalMedian(residuals).clamp(-8.0, 8.0);
      var squared = 0.0;
      for (final residual in residuals) {
        squared += math.pow(residual - offset, 2).toDouble();
      }
      final union = {...vector.keys, ...live.keys}.length;
      final score = math.sqrt(squared / common.length) +
          (union - common.length) * 6 / union +
          offset.abs() * .15;
      if (score <= 22) candidates.add(_Match(session, score, common.length));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.score.compareTo(b.score));
    final best = candidates.first;
    final otherFloors =
        candidates.where((m) => m.session.floor != best.session.floor);
    if (otherFloors.any((m) => m.score - best.score < 3)) return null;
    final neighbors = candidates
        .where((m) => m.session.floor == best.session.floor)
        .take(3)
        .toList();
    var ambiguous = false;
    for (final m in neighbors.skip(1)) {
      if (m.score - best.score < 3 && _distance(best.session, m.session) > 20) {
        ambiguous = true;
      }
    }
    // Use nearest surveyed point for disconnected corridors and exact matches.
    var x = best.session.xPct, y = best.session.yPct;
    if (!ambiguous && best.score > .001) {
      final local =
          neighbors.where((m) => _distance(best.session, m.session) <= 20);
      var sum = 0.0;
      x = 0;
      y = 0;
      for (final m in local) {
        final w = 1 / math.pow(m.score + 1, 2);
        sum += w;
        x += w * m.session.xPct;
        y += w * m.session.yPct;
      }
      x /= sum;
      y /= sum;
    }
    final matchedBeaconIds = signalVector(best.session.observations).keys.toSet();
    return PositionEstimate(
        floor: best.session.floor,
        xPct: x,
        yPct: y,
        quality: ambiguous || best.score > 12
            ? PositionQuality.low
            : PositionQuality.medium,
        observedAt: fresh
            .where((o) => matchedBeaconIds.contains(o.beaconId))
            .map((o) => o.observedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b),
        beaconCount: best.count,
        score: best.score);
  }

  double _distance(SurveySession a, SurveySession b) =>
      math.sqrt(math.pow(a.xPct - b.xPct, 2) + math.pow(a.yPct - b.yPct, 2));
}

class _Match {
  final SurveySession session;
  final double score;
  final int count;
  _Match(this.session, this.score, this.count);
}
