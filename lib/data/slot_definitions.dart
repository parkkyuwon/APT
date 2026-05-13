/// 웹 `src/shared/slot-definitions.js` 미러. 슬롯의 정적 메타(층/종류)만 보유.
/// 좌표(map_x/map_y)는 AppState.slotMapPositions 에서 동적으로 가져온다.
class SlotMeta {
  const SlotMeta({
    required this.slotId,
    required this.floorCode,
    required this.chargerType,
  });
  final String slotId;
  final String floorCode;
  final String chargerType;
}

const List<SlotMeta> slotMetas = <SlotMeta>[
  SlotMeta(slotId: 'fast50-1', floorCode: 'B1', chargerType: 'fast50'),
  SlotMeta(slotId: 'fast50-2', floorCode: 'B2', chargerType: 'fast50'),
  SlotMeta(slotId: 'fast50-3', floorCode: 'B2', chargerType: 'fast50'),
  SlotMeta(slotId: 'slow7-1', floorCode: 'B1', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-2', floorCode: 'B1', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-3', floorCode: 'B2', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-4', floorCode: 'B2', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-5', floorCode: 'B2', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-6', floorCode: 'B2', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-7', floorCode: 'B2', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-8', floorCode: 'B2', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-9', floorCode: 'B2', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-10', floorCode: 'B2', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow7-11', floorCode: 'B2', chargerType: 'slow7'),
  SlotMeta(slotId: 'slow3-1', floorCode: 'B1', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-2', floorCode: 'B1', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-3', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-4', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-5', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-6', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-7', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-8', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-9', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-10', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-11', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-12', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-13', floorCode: 'B2', chargerType: 'slow3'),
  SlotMeta(slotId: 'slow3-14', floorCode: 'B2', chargerType: 'slow3'),
];

final Map<String, SlotMeta> slotMetaById = <String, SlotMeta>{
  for (final m in slotMetas) m.slotId: m,
};

String floorCodeFor(String slotId) =>
    slotMetaById[slotId]?.floorCode ?? 'B1';
