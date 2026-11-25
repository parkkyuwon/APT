import '../core/json_utils.dart';
import 'charger_type.dart';
import 'parking_slot.dart';

/// /api/state 응답의 state 필드.
class AppState {
  AppState({
    this.stateVersion = 0,
    this.vehicleVerificationRequired = true,
    required this.adEnabled,
    required this.maintenanceMode,
    required this.chatRetentionDays,
    required this.popupNotice,
    required this.counts,
    required this.slots,
    required this.slotNames,
    required this.slotDetails,
    required this.slotImages,
    required this.slotMapPositions,
    this.beaconMappings = const {},
    this.beaconPositions = const {},
  });

  final int stateVersion;
  final bool vehicleVerificationRequired;
  final bool adEnabled;
  final bool maintenanceMode;
  final int chatRetentionDays;
  final PopupNotice popupNotice;
  final Map<String, int> counts;
  final Map<String, List<ParkingSlot>> slots;
  final Map<String, String> slotNames;
  final Map<String, SlotDetail> slotDetails;
  final Map<String, String> slotImages;
  final Map<String, SlotPosition> slotMapPositions;

  /// 비콘 안정 식별자 → 슬롯 ID. 관리자가 비콘 스캔 화면에서 매핑하면
  /// 향후 사용자 폰이 같은 비콘을 감지했을 때 해당 슬롯을 자동 식별 가능.
  /// (구버전 호환용 — 신규 데이터는 [beaconPositions] 사용)
  final Map<String, String> beaconMappings;

  /// 비콘 안정 식별자 → 지도상 위치([BeaconPosition]).
  /// 평면도 위 좌표(0~100%) + 층 정보를 함께 보관.
  final Map<String, BeaconPosition> beaconPositions;

  static AppState empty() => AppState(
        adEnabled: true,
        maintenanceMode: false,
        chatRetentionDays: 30,
        popupNotice: PopupNotice.disabled(),
        counts: {
          for (final t in chargerTypes) t.id: t.defaultCount,
        },
        slots: _generateDefaultSlots(),
        slotNames: const {},
        slotDetails: const {},
        slotImages: const {},
        slotMapPositions: const {},
      );

  factory AppState.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    final rawCounts = asMapOrNull(json['counts']) ?? const {};
    for (final t in chargerTypes) {
      counts[t.id] = asInt(rawCounts[t.id], t.defaultCount);
    }

    final slots = <String, List<ParkingSlot>>{};
    final rawSlots = asMapOrNull(json['slots']) ?? const {};
    if (rawSlots.isEmpty) {
      slots.addAll(_generateDefaultSlots(counts: counts));
    } else {
      rawSlots.forEach((typeId, list) {
        slots[asStr(typeId)] =
            asListOfMaps(list).map((m) => ParkingSlot.fromJson(m)).toList();
      });
    }

    final slotDetails = <String, SlotDetail>{};
    asMapOrNull(json['slotDetails'])?.forEach((key, value) {
      final m = asMapOrNull(value);
      if (m != null) slotDetails[asStr(key)] = SlotDetail.fromJson(m);
    });

    final slotNames = <String, String>{};
    asMapOrNull(json['slotNames'])?.forEach((k, v) {
      slotNames[asStr(k)] = asStr(v);
    });

    final slotImages = <String, String>{};
    asMapOrNull(json['slotImages'])?.forEach((k, v) {
      slotImages[asStr(k)] = asStr(v);
    });

    final slotMapPositions = <String, SlotPosition>{};
    asMapOrNull(json['slotMapPositions'])?.forEach((k, v) {
      final m = asMapOrNull(v);
      if (m != null) slotMapPositions[asStr(k)] = SlotPosition.fromJson(m);
    });

    final beaconMappings = <String, String>{};
    asMapOrNull(json['beaconMappings'])?.forEach((k, v) {
      final slot = asStr(v).trim();
      if (slot.isNotEmpty) beaconMappings[asStr(k)] = slot;
    });

    final beaconPositions = <String, BeaconPosition>{};
    asMapOrNull(json['beaconPositions'])?.forEach((k, v) {
      final m = asMapOrNull(v);
      if (m != null) beaconPositions[asStr(k)] = BeaconPosition.fromJson(m);
    });

    return AppState(
      stateVersion: asInt(json['stateVersion'], 0),
      vehicleVerificationRequired: json['vehicleVerificationRequired'] != false,
      adEnabled: json['adEnabled'] != false,
      maintenanceMode: asBool(json['maintenanceMode']),
      chatRetentionDays: asInt(json['chatRetentionDays'], 30),
      popupNotice: PopupNotice.fromJson(
        asMapOrNull(json['popupNotice']) ?? const {},
      ),
      counts: counts,
      slots: slots,
      slotNames: slotNames,
      slotDetails: slotDetails,
      slotImages: slotImages,
      slotMapPositions: slotMapPositions,
      beaconMappings: beaconMappings,
      beaconPositions: beaconPositions,
    );
  }

  static Map<String, List<ParkingSlot>> _generateDefaultSlots(
      {Map<String, int>? counts}) {
    final c = counts ?? {for (final t in chargerTypes) t.id: t.defaultCount};
    final out = <String, List<ParkingSlot>>{};
    for (final t in chargerTypes) {
      final n = c[t.id] ?? t.defaultCount;
      out[t.id] = List<ParkingSlot>.generate(
        n,
        (i) => ParkingSlot(id: '${t.id}-${i + 1}', typeId: t.id),
      );
    }
    return out;
  }

  int totalSlots() => slots.values.fold(0, (sum, list) => sum + list.length);

  int occupiedSlots() {
    var n = 0;
    for (final entry in slots.entries) {
      for (final slot in entry.value) {
        final d = slotDetails[slot.id];
        if (d != null && d.isOccupied) n++;
      }
    }
    return n;
  }

  /// 영속 캐시(StateCache) 직렬화용. fromJson 과 대응.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stateVersion': stateVersion,
      'vehicleVerificationRequired': vehicleVerificationRequired,
      'adEnabled': adEnabled,
      'maintenanceMode': maintenanceMode,
      'chatRetentionDays': chatRetentionDays,
      'popupNotice': popupNotice.toJson(),
      'counts': counts,
      'slots': slots.map(
        (k, list) => MapEntry(k, list.map((s) => s.toJson()).toList()),
      ),
      'slotNames': slotNames,
      'slotDetails': slotDetails.map((k, d) => MapEntry(k, d.toJson())),
      'slotImages': slotImages,
      'slotMapPositions':
          slotMapPositions.map((k, p) => MapEntry(k, p.toJson())),
      'beaconMappings': beaconMappings,
      'beaconPositions': beaconPositions.map((k, p) => MapEntry(k, p.toJson())),
    };
  }
}

/// 비콘 위치 — 평면도 위 좌표(0~100%) + 층 코드.
class BeaconPosition {
  const BeaconPosition({
    required this.floor,
    required this.x,
    required this.y,
  });

  final String floor; // 'B1' | 'B2'
  final double x;
  final double y;

  factory BeaconPosition.fromJson(Map<String, dynamic> json) => BeaconPosition(
        floor: () {
          final f = asStr(json['floor']);
          return f.isEmpty ? 'B1' : f;
        }(),
        x: asDouble(json['x']),
        y: asDouble(json['y']),
      );

  Map<String, dynamic> toJson() => {'floor': floor, 'x': x, 'y': y};
}

class PopupNotice {
  PopupNotice({
    required this.enabled,
    required this.content,
    required this.autoCloseSeconds,
  });

  factory PopupNotice.disabled() =>
      PopupNotice(enabled: false, content: '', autoCloseSeconds: 0);

  factory PopupNotice.fromJson(Map<String, dynamic> json) => PopupNotice(
        enabled: asBool(json['enabled']),
        content: asStr(json['content']),
        autoCloseSeconds: asInt(json['autoCloseSeconds']),
      );

  final bool enabled;
  final String content;
  final int autoCloseSeconds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'content': content,
        'autoCloseSeconds': autoCloseSeconds,
      };
}

class SlotPosition {
  const SlotPosition({this.floor = '', required this.x, required this.y});
  final String floor; // 'B1' | 'B2' | '' (구버전 호환)
  final double x;
  final double y;

  factory SlotPosition.fromJson(Map<String, dynamic> json) => SlotPosition(
        floor: asStr(json['floor']),
        x: asDouble(json['x']),
        y: asDouble(json['y']),
      );

  Map<String, dynamic> toJson() => {'floor': floor, 'x': x, 'y': y};
}
