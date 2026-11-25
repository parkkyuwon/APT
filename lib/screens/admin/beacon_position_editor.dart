import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';
import '../../providers/app_state_provider.dart';

/// 평면도 이미지의 실제 픽셀 비율(가로/세로).
const Map<String, double> _floorAspectRatio = {
  'B1': 2047 / 1877,
  'B2': 3920 / 2240,
};

/// 비콘의 지도 위치 편집. 비콘 스캔 화면에서 "지도에 위치 지정" 으로 진입.
/// B1/B2 평면도 위에 핀치 줌 가능한 지도를 띄우고, 사용자가 탭한 지점을
/// 해당 비콘의 새 좌표로 저장.
class BeaconPositionEditor extends StatefulWidget {
  const BeaconPositionEditor({
    super.key,
    required this.beaconId,
    required this.beaconName,
  });

  final String beaconId;
  final String beaconName;

  @override
  State<BeaconPositionEditor> createState() => _BeaconPositionEditorState();
}

class _BeaconPositionEditorState extends State<BeaconPositionEditor> {
  String _floor = 'B1';
  double? _x; // 0~100 %
  double? _y; // 0~100 %
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppStateProvider>();
    final existing = app.state.beaconPositions[widget.beaconId];
    if (existing != null) {
      _floor = existing.floor;
      _x = existing.x;
      _y = existing.y;
    }
  }

  void _onCanvasTap(double pctX, double pctY) {
    setState(() {
      _x = pctX.clamp(0.0, 100.0).toDouble();
      _y = pctY.clamp(0.0, 100.0).toDouble();
    });
  }

  Future<void> _save() async {
    if (_x == null || _y == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppStateProvider>();
    setState(() => _saving = true);
    try {
      await app.upsertBeaconPosition(
        beaconId: widget.beaconId,
        position: BeaconPosition(floor: _floor, x: _x!, y: _y!),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
          '비콘 위치 저장: $_floor ${_x!.toStringAsFixed(1)}%, ${_y!.toStringAsFixed(1)}%',
        ),
        backgroundColor: Colors.green.shade700,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('저장 실패: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppStateProvider>();
    setState(() => _saving = true);
    try {
      await app.upsertBeaconPosition(
        beaconId: widget.beaconId,
        position: null,
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('비콘 위치 매핑 해제')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('해제 실패: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPosition = _x != null && _y != null;
    return DefaultTabController(
      length: 2,
      initialIndex: _floor == 'B1' ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('비콘 설치 위치 지정'),
          bottom: TabBar(
            tabs: const [Tab(text: 'B1'), Tab(text: 'B2')],
            onTap: (i) => setState(() => _floor = i == 0 ? 'B1' : 'B2'),
          ),
          actions: [
            if (_x != null)
              IconButton(
                tooltip: '매핑 해제',
                onPressed: _saving ? null : _clear,
                icon: const Icon(Icons.link_off),
              ),
            IconButton(
              tooltip: '저장',
              onPressed: !_saving && hasPosition ? _save : null,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surfaceContainer,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.beaconName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(widget.beaconId,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.touch_app, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hasPosition
                              ? '현재 좌표: $_floor / x ${_x!.toStringAsFixed(1)}%, y ${_y!.toStringAsFixed(1)}%'
                              : '평면도의 비콘 설치 위치를 탭하세요.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _FloorCanvas(
                    floorCode: 'B1',
                    pinX: _floor == 'B1' ? _x : null,
                    pinY: _floor == 'B1' ? _y : null,
                    onTap: (x, y) {
                      _floor = 'B1';
                      _onCanvasTap(x, y);
                    },
                  ),
                  _FloorCanvas(
                    floorCode: 'B2',
                    pinX: _floor == 'B2' ? _x : null,
                    pinY: _floor == 'B2' ? _y : null,
                    onTap: (x, y) {
                      _floor = 'B2';
                      _onCanvasTap(x, y);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorCanvas extends StatefulWidget {
  const _FloorCanvas({
    required this.floorCode,
    required this.pinX,
    required this.pinY,
    required this.onTap,
  });
  final String floorCode;
  final double? pinX;
  final double? pinY;
  final void Function(double pctX, double pctY) onTap;

  @override
  State<_FloorCanvas> createState() => _FloorCanvasState();
}

class _FloorCanvasState extends State<_FloorCanvas> {
  final TransformationController _viewerCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    _viewerCtrl.addListener(_rebuildOnZoom);
  }

  @override
  void dispose() {
    _viewerCtrl.removeListener(_rebuildOnZoom);
    _viewerCtrl.dispose();
    super.dispose();
  }

  void _rebuildOnZoom() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _floorAspectRatio[widget.floorCode] ?? 1.0;
    final scale = _viewerCtrl.value.getMaxScaleOnAxis();
    final inverse = scale == 0 ? 1.0 : 1.0 / scale;

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
            aspectRatio: ratio,
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
                          widget.onTap(pctX, pctY);
                        },
                        child: Image.asset(
                          'assets/images/${widget.floorCode}.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    if (widget.pinX != null && widget.pinY != null)
                      Positioned(
                        left: (widget.pinX! / 100.0) * w,
                        top: (widget.pinY! / 100.0) * h,
                        child: Transform.translate(
                          offset: const Offset(-16, -16),
                          child: Transform.scale(
                            scale: inverse,
                            alignment: Alignment.center,
                            child: _BeaconPin(),
                          ),
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

class _BeaconPin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.purple.shade600,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.bluetooth, color: Colors.white, size: 18),
    );
  }
}
