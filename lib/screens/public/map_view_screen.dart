import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/slot_definitions.dart';
import '../../models/app_state.dart';
import '../../models/parking_slot.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/slot_dialog.dart';

/// 평면도 이미지의 실제 픽셀 비율(가로/세로). 마커 좌표 정확도 유지를 위해 사용.
const Map<String, double> _floorAspectRatio = {
  'B1': 2047 / 1877,
  'B2': 3920 / 2240,
};

/// 웹 `parking-list.html` / `map-editor.html` 의 평면도 보기 미러.
/// B1/B2 평면도 이미지 위에 슬롯 좌표(slotMapPositions)에 마커를 띄우고,
/// 마커를 탭하면 기존 슬롯 다이얼로그를 연다. 핀치 줌·드래그 지원.
class MapViewScreen extends StatelessWidget {
  const MapViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('지도 보기'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'B1'),
              Tab(text: 'B2'),
            ],
          ),
        ),
        body: const FloorMapView(),
      ),
    );
  }
}

/// 홈 등에 임베드 가능한 B1/B2 탭 + 평면도 + 마커 본체.
/// 가로 스와이프는 비활성화 — 탭 클릭으로만 층 전환 (핀치 줌·팬 제스처 보호).
class FloorMapView extends StatelessWidget {
  const FloorMapView({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabBarView(
      physics: NeverScrollableScrollPhysics(),
      children: [
        _FloorMap(floorCode: 'B1'),
        _FloorMap(floorCode: 'B2'),
      ],
    );
  }
}

class _FloorMap extends StatefulWidget {
  const _FloorMap({required this.floorCode});
  final String floorCode;

  @override
  State<_FloorMap> createState() => _FloorMapState();
}

class _FloorMapState extends State<_FloorMap> {
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

  Future<void> _openSlot(BuildContext context, ParkingSlot slot) async {
    final auth = context.read<AuthProvider>();
    final app = context.read<AppStateProvider>();
    final session = auth.session;
    if (session == null) return;
    final detail = app.state.slotDetails[slot.id] ?? const SlotDetail();
    final result = await showSlotDialog(
      context,
      slot: slot,
      currentDetail: detail,
      appState: app.state,
      session: session,
    );
    if (result == null) return;
    try {
      switch (result.action) {
        case SlotDialogAction.park:
          if (result.detail != null) {
            await app.upsertSlotDetail(slotId: slot.id, detail: result.detail!);
          }
          break;
        case SlotDialogAction.checkout:
          await app.clearSlotDetail(slot.id);
          break;
        case SlotDialogAction.toggleBlocked:
          await app.toggleSlotBlocked(slot.id);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final state = app.state;

    final floorSlots = <ParkingSlot>[];
    for (final list in state.slots.values) {
      for (final s in list) {
        final pos = state.slotMapPositions[s.id];
        final slotFloor = (pos != null && pos.floor.isNotEmpty)
            ? pos.floor
            : floorCodeFor(s.id);
        if (slotFloor == widget.floorCode) {
          floorSlots.add(s);
        }
      }
    }

    final aspectRatio = _floorAspectRatio[widget.floorCode] ?? 1.0;
    final scale = _viewerCtrl.value.getMaxScaleOnAxis();
    final inverseScale = scale == 0 ? 1.0 : 1.0 / scale;

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: InteractiveViewer(
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
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/${widget.floorCode}.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    for (final slot in floorSlots)
                      _MapMarker(
                        slot: slot,
                        detail: state.slotDetails[slot.id],
                        position: state.slotMapPositions[slot.id],
                        parentSize: Size(c.maxWidth, c.maxHeight),
                        inverseScale: inverseScale,
                        onTap: () => _openSlot(context, slot),
                      ),
                    if (floorSlots.isEmpty)
                      const Positioned.fill(
                        child: Center(
                          child: Text('이 층에 등록된 슬롯이 없습니다.'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.slot,
    required this.detail,
    required this.position,
    required this.parentSize,
    required this.inverseScale,
    required this.onTap,
  });

  final ParkingSlot slot;
  final SlotDetail? detail;
  final SlotPosition? position;
  final Size parentSize;
  final double inverseScale;
  final VoidCallback onTap;

  /// 차단 상태일 때만 우상단 코너 점 색을 반환. 그 외 null.
  Color? get _statusBadgeColor {
    final d = detail;
    if (d != null && d.parkingBlocked) return AppColors.maintenance;
    return null;
  }

  /// 사용 중이면 회색, 아니면 충전기 종류 색으로 채움.
  Color _fillFor(Color typeColor) {
    final d = detail;
    if (d != null && !d.parkingBlocked && d.isOccupied) {
      return Colors.grey.shade500;
    }
    return typeColor;
  }

  @override
  Widget build(BuildContext context) {
    final p = position;
    if (p == null) return const SizedBox.shrink();
    const markerSize = 28.0;
    final left = (p.x / 100.0) * parentSize.width;
    final top = (p.y / 100.0) * parentSize.height;
    final shortId = slot.id.split('-').last;
    final typeColor = ChargerColors.forTypeId(slot.typeId);
    final fillColor = _fillFor(typeColor);
    final badge = _statusBadgeColor;

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
            child: SizedBox(
              width: markerSize,
              height: markerSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: markerSize,
                    height: markerSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fillColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: typeColor, width: 3),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(0, 1)),
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
                  if (badge != null)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: badge,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
