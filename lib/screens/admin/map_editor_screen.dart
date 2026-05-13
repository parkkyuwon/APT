import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/slot_definitions.dart';
import '../../models/app_state.dart';
import '../../models/parking_slot.dart';
import '../../providers/app_state_provider.dart';
import '../../theme.dart';

/// 평면도 이미지의 실제 픽셀 비율(가로/세로). 마커 좌표 정확도 유지를 위해 사용.
const Map<String, double> _floorAspectRatio = {
  'B1': 2047 / 1877,
  'B2': 3920 / 2240,
};

/// [map-editor.html] 의 Flutter 미러.
///
/// - B1/B2 탭으로 층 전환
/// - 평면도 이미지 위에 슬롯 마커 표시 (선택된 슬롯은 빨간 외곽선)
/// - 핀치 줌·팬 지원
/// - 슬롯 칩을 누르면 해당 슬롯이 선택 상태가 되고,
///   평면도 이미지를 탭하면 그 위치가 선택된 슬롯의 좌표(0~100%)로 설정됨
/// - 우상단 저장 버튼으로 변경된 좌표를 한 번에 백엔드로 저장
class MapEditorScreen extends StatefulWidget {
  const MapEditorScreen({super.key});

  @override
  State<MapEditorScreen> createState() => _MapEditorScreenState();
}

class _MapEditorScreenState extends State<MapEditorScreen> {
  String? _selectedSlotId;
  Map<String, SlotPosition> _positions = {};
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final app = context.read<AppStateProvider>();
    setState(() {
      _positions = Map.of(app.state.slotMapPositions);
      _dirty = false;
    });
  }

  void _selectSlot(String slotId) {
    setState(() => _selectedSlotId = slotId);
  }

  void _handleCanvasTap(double pctX, double pctY, String floorCode) {
    final id = _selectedSlotId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먼저 아래 칩에서 좌표를 지정할 충전기를 선택하세요.'),
        ),
      );
      return;
    }
    final clampedX = pctX.clamp(0.0, 100.0).toDouble();
    final clampedY = pctY.clamp(0.0, 100.0).toDouble();
    setState(() {
      _positions[id] =
          SlotPosition(floor: floorCode, x: clampedX, y: clampedY);
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppStateProvider>();
    final payload = _payload(app.state);
    payload['slotMapPositions'] =
        _positions.map((k, v) => MapEntry(k, v.toJson()));
    try {
      await app.saveFullState(payload);
      setState(() => _dirty = false);
      messenger.showSnackBar(const SnackBar(content: Text('좌표가 저장되었습니다.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, dynamic> _payload(AppState s) {
    final slotDetails = <String, dynamic>{};
    s.slotDetails.forEach((id, d) => slotDetails[id] = d.toJson());
    final slots = <String, dynamic>{};
    s.slots.forEach((k, list) => slots[k] = list.map((e) => e.toJson()).toList());
    return <String, dynamic>{
      'adEnabled': s.adEnabled,
      'maintenanceMode': s.maintenanceMode,
      'chatRetentionDays': s.chatRetentionDays,
      'popupNotice': <String, dynamic>{
        'enabled': s.popupNotice.enabled,
        'content': s.popupNotice.content,
        'autoCloseSeconds': s.popupNotice.autoCloseSeconds,
      },
      'counts': Map<String, int>.from(s.counts),
      'slots': slots,
      'slotNames': Map<String, String>.from(s.slotNames),
      'slotImages': Map<String, String>.from(s.slotImages),
      'slotDetails': slotDetails,
      'beaconMappings': Map<String, String>.from(s.beaconMappings),
      'beaconPositions':
          s.beaconPositions.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final state = app.state;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('지도 편집'),
          bottom: const TabBar(
            tabs: [Tab(text: 'B1'), Tab(text: 'B2')],
          ),
          actions: [
            IconButton(
              tooltip: '되돌리기',
              onPressed: _dirty ? _load : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: '저장',
              onPressed: _dirty ? _save : null,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _FloorEditor(
              floorCode: 'B1',
              state: state,
              positions: _positions,
              selectedSlotId: _selectedSlotId,
              onSelectSlot: _selectSlot,
              onCanvasTap: _handleCanvasTap,
            ),
            _FloorEditor(
              floorCode: 'B2',
              state: state,
              positions: _positions,
              selectedSlotId: _selectedSlotId,
              onSelectSlot: _selectSlot,
              onCanvasTap: _handleCanvasTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorEditor extends StatelessWidget {
  const _FloorEditor({
    required this.floorCode,
    required this.state,
    required this.positions,
    required this.selectedSlotId,
    required this.onSelectSlot,
    required this.onCanvasTap,
  });

  final String floorCode;
  final AppState state;
  final Map<String, SlotPosition> positions;
  final String? selectedSlotId;
  final void Function(String slotId) onSelectSlot;
  final void Function(double pctX, double pctY, String floorCode) onCanvasTap;

  List<ParkingSlot> get _floorSlots {
    final list = <ParkingSlot>[];
    for (final slots in state.slots.values) {
      for (final s in slots) {
        final pos = positions[s.id];
        final slotFloor = (pos != null && pos.floor.isNotEmpty)
            ? pos.floor
            : floorCodeFor(s.id);
        if (slotFloor == floorCode) list.add(s);
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _floorSlots;
    final selectedPos =
        selectedSlotId == null ? null : positions[selectedSlotId!];

    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: _FloorCanvas(
                floorCode: floorCode,
                slots: slots,
                positions: positions,
                selectedSlotId: selectedSlotId,
                onSelectSlot: onSelectSlot,
                onCanvasTap: onCanvasTap,
              ),
            ),
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.touch_app, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      selectedSlotId == null
                          ? '좌표를 지정할 충전기를 아래 목록에서 선택한 뒤, 평면도의 위치를 탭하세요.'
                          : '선택됨: $selectedSlotId · '
                              '${selectedPos == null ? '좌표 없음' : 'x ${selectedPos.x.toStringAsFixed(2)}%, y ${selectedPos.y.toStringAsFixed(2)}%'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: slots.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final s = slots[i];
                    final selected = s.id == selectedSlotId;
                    final hasPos = positions[s.id] != null;
                    final color = ChargerColors.forTypeId(s.typeId);
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) => onSelectSlot(s.id),
                      avatar: CircleAvatar(
                        backgroundColor: color,
                        radius: 8,
                      ),
                      label: Text(
                        '${s.id}${hasPos ? '' : ' ⚠'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloorCanvas extends StatefulWidget {
  const _FloorCanvas({
    required this.floorCode,
    required this.slots,
    required this.positions,
    required this.selectedSlotId,
    required this.onSelectSlot,
    required this.onCanvasTap,
  });

  final String floorCode;
  final List<ParkingSlot> slots;
  final Map<String, SlotPosition> positions;
  final String? selectedSlotId;
  final void Function(String slotId) onSelectSlot;
  final void Function(double pctX, double pctY, String floorCode) onCanvasTap;

  @override
  State<_FloorCanvas> createState() => _FloorCanvasState();
}

class _FloorCanvasState extends State<_FloorCanvas> {
  final TransformationController _viewerCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    _viewerCtrl.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _viewerCtrl.removeListener(_onTransformChanged);
    _viewerCtrl.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _floorAspectRatio[widget.floorCode] ?? 1.0;
    final scale = _viewerCtrl.value.getMaxScaleOnAxis();
    final inverseScale = scale == 0 ? 1.0 : 1.0 / scale;

    return InteractiveViewer(
      transformationController: _viewerCtrl,
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.8,
      maxScale: 6.0,
      boundaryMargin: const EdgeInsets.all(80),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(
          builder: (ctx, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final pctX = (details.localPosition.dx / w) * 100;
                      final pctY = (details.localPosition.dy / h) * 100;
                      widget.onCanvasTap(pctX, pctY, widget.floorCode);
                    },
                    child: Image.asset(
                      'assets/images/${widget.floorCode}.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
                for (final slot in widget.slots)
                  _EditorMarker(
                    slot: slot,
                    position: widget.positions[slot.id],
                    selected: slot.id == widget.selectedSlotId,
                    parentSize: Size(w, h),
                    inverseScale: inverseScale,
                    onTap: () => widget.onSelectSlot(slot.id),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EditorMarker extends StatelessWidget {
  const _EditorMarker({
    required this.slot,
    required this.position,
    required this.selected,
    required this.parentSize,
    required this.inverseScale,
    required this.onTap,
  });

  final ParkingSlot slot;
  final SlotPosition? position;
  final bool selected;
  final Size parentSize;
  final double inverseScale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = position;
    if (p == null) return const SizedBox.shrink();
    const markerSize = 28.0;
    final left = (p.x / 100.0) * parentSize.width;
    final top = (p.y / 100.0) * parentSize.height;
    final shortId = slot.id.split('-').last;
    final typeColor = ChargerColors.forTypeId(slot.typeId);
    final outlineColor = selected ? Colors.red : typeColor;
    final fillColor = typeColor;

    return Positioned(
      left: left,
      top: top,
      child: Transform.translate(
        offset: const Offset(-markerSize / 2, -markerSize / 2),
        child: Transform.scale(
          scale: inverseScale,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: markerSize,
              height: markerSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fillColor,
                shape: BoxShape.circle,
                border: Border.all(color: outlineColor, width: selected ? 4 : 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
              child: Text(
                shortId,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
