import 'app_state.dart';
import 'indoor_positioning.dart';

/// Versioned server-owned publication; private home coordinates are never included.
class PublishedIndoorDataset {
  PublishedIndoorDataset(
      {required this.revision,
      required this.enabled,
      required List<SurveySession> surveys,
      this.mapVersion = 'simplified-v1',
      Map<String, BeaconPosition> beaconPositions = const {}})
      : surveys = List.unmodifiable(surveys),
        beaconPositions = Map.unmodifiable(beaconPositions) {
    if (revision < 0 ||
        mapVersion != 'simplified-v1' ||
        surveys.length > 500 ||
        surveys.fold<int>(0, (count, s) => count + s.observations.length) >
            20000 ||
        surveys.map((s) => s.id).toSet().length != surveys.length ||
        surveys.any((s) =>
            s.accountScope != 'published' ||
            s.siteId != 'home' ||
            !const ['B1', 'B2'].contains(s.floor) ||
            s.mapVersion != mapVersion ||
            !s.usable) ||
        beaconPositions.entries.any((e) =>
            e.key.trim().isEmpty ||
            !const ['B1', 'B2'].contains(e.value.floor) ||
            !_validCoordinate(e.value.x) ||
            !_validCoordinate(e.value.y))) {
      throw const FormatException('Invalid shared indoor data');
    }
  }
  final int revision;
  final bool enabled;
  final String mapVersion;
  final List<SurveySession> surveys;
  final Map<String, BeaconPosition> beaconPositions;
  bool get usable => enabled && surveys.isNotEmpty;
  static bool _validCoordinate(double n) => n.isFinite && n >= 0 && n <= 100;
  factory PublishedIndoorDataset.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['siteId'] != 'home' ||
        json['revision'] is! int ||
        json['enabled'] is! bool ||
        json['surveys'] is! List ||
        json['mapVersion'] is! String) {
      throw const FormatException('Unsupported shared indoor data');
    }
    final records = json['surveys'] as List;
    if (records.length > 500) {
      throw const FormatException('Too many survey sessions');
    }
    var observationCount = 0;
    for (final record in records) {
      if (record is! Map || record['observations'] is! List) {
        throw const FormatException('Invalid shared survey');
      }
      observationCount += (record['observations'] as List).length;
      if (observationCount > 20000) {
        throw const FormatException('Too many beacon observations');
      }
    }
    final rawPositions = json['beaconPositions'] ?? const <String, dynamic>{};
    if (rawPositions is! Map) {
      throw const FormatException('Invalid installed positions');
    }
    final positions = <String, BeaconPosition>{};
    for (final entry in rawPositions.entries) {
      final raw = entry.value;
      if (entry.key is! String ||
          raw is! Map ||
          raw['floor'] is! String ||
          raw['x'] is! num ||
          raw['y'] is! num) {
        throw const FormatException('Invalid installed position');
      }
      positions[entry.key as String] = BeaconPosition(
          floor: raw['floor'] as String,
          x: (raw['x'] as num).toDouble(),
          y: (raw['y'] as num).toDouble());
    }
    return PublishedIndoorDataset(
        revision: json['revision'] as int,
        enabled: json['enabled'] as bool,
        mapVersion: json['mapVersion'] as String,
        surveys: records
            .map((s) =>
                SurveySession.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
        beaconPositions: positions);
  }
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'revision': revision,
        'enabled': enabled,
        'siteId': 'home',
        'mapVersion': mapVersion,
        'surveys': surveys.map((s) => s.toJson()).toList(),
        'beaconPositions':
            beaconPositions.map((id, p) => MapEntry(id, p.toJson()))
      };
}
