/// All indoor display coordinates are percentages, including values below 1.
void validateIndoorPoint(double x, double y) {
  if (!x.isFinite || !y.isFinite || x < 0 || x > 100 || y < 0 || y > 100) {
    throw ArgumentError(
        'Indoor coordinates must be finite percentages (0..100).');
  }
}

class BeaconObservation {
  final String beaconId;
  final int rssi;
  final DateTime observedAt;
  final int? measuredPower;
  BeaconObservation(
      {required this.beaconId,
      required this.rssi,
      required this.observedAt,
      this.measuredPower}) {
    if (beaconId.isEmpty ||
        rssi >= 0 ||
        rssi < -127 ||
        (measuredPower != null &&
            (measuredPower! >= 0 || measuredPower! < -127))) {
      throw ArgumentError('Invalid beacon signal.');
    }
  }
  Map<String, dynamic> toJson() => {
        'beaconId': beaconId,
        'rssi': rssi,
        'observedAt': observedAt.toUtc().toIso8601String(),
        'measuredPower': measuredPower
      };
  factory BeaconObservation.fromJson(Map<String, dynamic> j) =>
      BeaconObservation(
          beaconId: j['beaconId'] as String,
          rssi: j['rssi'] as int,
          observedAt: DateTime.parse(j['observedAt'] as String),
          measuredPower: j['measuredPower'] as int?);
}

class SurveySession {
  final String id, accountScope, siteId, floor, mapVersion, label, deviceGroup;
  final double xPct, yPct;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<BeaconObservation> observations;
  final bool excluded;
  SurveySession(
      {required this.id,
      required this.accountScope,
      this.siteId = 'home',
      required this.floor,
      this.mapVersion = 'simplified-v1',
      required this.xPct,
      required this.yPct,
      required this.startedAt,
      this.endedAt,
      List<BeaconObservation> observations = const [],
      this.excluded = false,
      this.label = '',
      this.deviceGroup = 'local'})
      : observations = List.unmodifiable(observations) {
    validateIndoorPoint(xPct, yPct);
    if (id.isEmpty ||
        accountScope.isEmpty ||
        siteId.isEmpty ||
        floor.isEmpty ||
        mapVersion.isEmpty ||
        (endedAt != null && endedAt!.isBefore(startedAt))) {
      throw ArgumentError('Invalid survey session.');
    }
    if (observations.any((o) =>
        o.observedAt.isBefore(startedAt) ||
        (endedAt != null && o.observedAt.isAfter(endedAt!)))) {
      throw ArgumentError('Observation outside survey interval.');
    }
  }
  bool get isComplete => endedAt != null;
  bool get usable => isComplete && !excluded && observations.isNotEmpty;
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'coordinateUnit': 'percent',
        'id': id,
        'accountScope': accountScope,
        'siteId': siteId,
        'floor': floor,
        'mapVersion': mapVersion,
        'xPct': xPct,
        'yPct': yPct,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt?.toUtc().toIso8601String(),
        'observations': observations.map((o) => o.toJson()).toList(),
        'excluded': excluded,
        'label': label,
        'deviceGroup': deviceGroup
      };
  factory SurveySession.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1 || j['coordinateUnit'] != 'percent') {
      throw const FormatException(
          'Unsupported indoor survey schema or coordinate unit.');
    }
    return SurveySession(
        id: j['id'] as String,
        accountScope: j['accountScope'] as String,
        siteId: j['siteId'] as String,
        floor: j['floor'] as String,
        mapVersion: j['mapVersion'] as String,
        xPct: (j['xPct'] as num).toDouble(),
        yPct: (j['yPct'] as num).toDouble(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: j['endedAt'] == null
            ? null
            : DateTime.parse(j['endedAt'] as String),
        observations: (j['observations'] as List)
            .map((o) =>
                BeaconObservation.fromJson(Map<String, dynamic>.from(o as Map)))
            .toList(),
        excluded: j['excluded'] as bool? ?? false,
        label: j['label'] as String? ?? '',
        deviceGroup: j['deviceGroup'] as String? ?? 'local');
  }
}

enum PositionQuality { low, medium, high }

class PositionEstimate {
  final String floor;
  final double xPct, yPct, score;
  final PositionQuality quality;
  final DateTime observedAt;
  final int beaconCount;
  final String source;
  const PositionEstimate(
      {required this.floor,
      required this.xPct,
      required this.yPct,
      required this.quality,
      required this.observedAt,
      required this.beaconCount,
      required this.score,
      this.source = 'fingerprint'});
}

/// A signal region is evidence for a site visit, never an installed coordinate.
class BeaconEstimate {
  final String beaconId, floor, mapVersion;
  final double xPct, yPct, spreadPct;
  final int pointCount;
  final bool isMetric;
  final double? residualDb;
  bool get confirmed => false;
  const BeaconEstimate(
      {required this.beaconId,
      required this.floor,
      required this.mapVersion,
      required this.xPct,
      required this.yPct,
      required this.spreadPct,
      required this.pointCount,
      this.isMetric = false,
      this.residualDb});
}
