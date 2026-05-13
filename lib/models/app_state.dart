import 'charger_type.dart';
import 'parking_slot.dart';

/// /api/state 응답의 state 필드.
class AppState {
  AppState({
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
    final rawCounts = (json['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final t in chargerTypes) {
      counts[t.id] = (rawCounts[t.id] as num?)?.toInt() ?? t.defaultCount;
    }

    final slots = <String, List<ParkingSlot>>{};
    final rawSlots = (json['slots'] as Map?)?.cast<String, dynamic>() ?? const {};
    if (rawSlots.isEmpty) {
      slots.addAll(_generateDefaultSlots(counts: counts));
    } else {
      rawSlots.forEach((typeId, list) {
        slots[typeId] = (list as List)
            .map((e) => ParkingSlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    }

    final slotDetails = <String, SlotDetail>{};
    (json['slotDetails'] as Map?)?.forEach((key, value) {
      slotDetails[key as String] = SlotDetail.fromJson(Map<String, dynamic>.from(value as Map));
    });

    final slotNames = <String, String>{};
    (json['slotNames'] as Map?)?.forEach((k, v) => slotNames[k as String] = v?.toString() ?? '');

    final slotImages = <String, String>{};
    (json['slotImages'] as Map?)?.forEach((k, v) => slotImages[k as String] = v?.toString() ?? '');

    final slotMapPositions = <String, SlotPosition>{};
    (json['slotMapPositions'] as Map?)?.forEach((k, v) {
      if (v is Map) {
        slotMapPositions[k as String] =
            SlotPosition.fromJson(Map<String, dynamic>.from(v));
      }
    });

    final beaconMappings = <String, String>{};
    (json['beaconMappings'] as Map?)?.forEach((k, v) {
      final slot = v?.toString().trim() ?? '';
      if (slot.isNotEmpty) beaconMappings[k as String] = slot;
    });

    final beaconPositions = <String, BeaconPosition>{};
    (json['beaconPositions'] as Map?)?.forEach((k, v) {
      if (v is Map) {
        beaconPositions[k as String] =
            BeaconPosition.fromJson(Map<String, dynamic>.from(v));
      }
    });

    return AppState(
      adEnabled: json['adEnabled'] != false,
      maintenanceMode: json['maintenanceMode'] == true,
      chatRetentionDays: (json['chatRetentionDays'] as num?)?.toInt() ?? 30,
      popupNotice: PopupNotice.fromJson(
        (json['popupNotice'] as Map?)?.cast<String, dynamic>() ?? const {},
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

  static Map<String, List<ParkingSlot>> _generateDefaultSlots({Map<String, int>? counts}) {
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
      'beaconPositions':
          beaconPositions.map((k, p) => MapEntry(k, p.toJson())),
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
        floor: (json['floor'] as String?) ?? 'B1',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
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
        enabled: json['enabled'] == true,
        content: (json['content'] as String?) ?? '',
        autoCloseSeconds: (json['autoCloseSeconds'] as num?)?.toInt() ?? 0,
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
        floor: (json['floor'] as String?) ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'floor': floor, 'x': x, 'y': y};
}
