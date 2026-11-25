import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';

import '../../core/bluetooth_permissions.dart';
import '../../models/app_state.dart';
import '../../providers/app_state_provider.dart';
import 'beacon_position_editor.dart';

/// 평면도 이미지의 실제 픽셀 비율(가로/세로).
const Map<String, double> _floorAspectRatio = {
  'B1': 2047 / 1877,
  'B2': 3920 / 2240,
};

/// 등록된 비콘(좌표 매핑이 있는) 의 목록·지도 보기.
/// 리스트 탭 — 모든 매핑 + 편집/삭제, 지도 탭 — B1/B2 평면도에 핀 오버레이.
class ConsoleBeaconList extends StatelessWidget {
  const ConsoleBeaconList({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('등록된 비콘'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '목록'),
              Tab(text: 'B1'),
              Tab(text: 'B2'),
              Tab(text: '현위치'),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            _BeaconListView(),
            _BeaconMapView(floor: 'B1'),
            _BeaconMapView(floor: 'B2'),
            _LivePositionView(),
          ],
        ),
      ),
    );
  }
}

/// 비콘 ID(stable) 를 사람에게 이해하기 좋게 풀어쓴다.
/// ib:UUID:major:minor → "iBeacon\nUUID\nMajor: x  Minor: y"
/// mac:AA:BB:... → "BLE\nAA:BB:CC:..."
class _BeaconLabel {
  _BeaconLabel({required this.kind, required this.line1, required this.line2});
  final String kind;
  final String line1;
  final String line2;

  static _BeaconLabel parse(String stableId) {
    if (stableId.startsWith('ib:')) {
      final rest = stableId.substring(3);
      final colonIdx = rest.lastIndexOf(':');
      if (colonIdx > 0) {
        final beforeMinor = rest.substring(0, colonIdx);
        final minor = rest.substring(colonIdx + 1);
        final beforeMajor = beforeMinor.lastIndexOf(':');
        if (beforeMajor > 0) {
          final uuid = beforeMinor.substring(0, beforeMajor);
          final major = beforeMinor.substring(beforeMajor + 1);
          return _BeaconLabel(
            kind: 'iBeacon',
            line1: uuid,
            line2: 'Major $major · Minor $minor',
          );
        }
      }
      return _BeaconLabel(kind: 'iBeacon', line1: rest, line2: '');
    }
    if (stableId.startsWith('mac:')) {
      return _BeaconLabel(
        kind: 'BLE',
        line1: stableId.substring(4),
        line2: '',
      );
    }
    return _BeaconLabel(kind: 'BLE', line1: stableId, line2: '');
  }
}

class _BeaconListView extends StatelessWidget {
  const _BeaconListView();

  @override
  Widget build(BuildContext context) {
    final positions = context.watch<AppStateProvider>().state.beaconPositions;
    if (positions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '등록된 비콘이 없습니다.\n관리자 콘솔 → 비콘 스캔 화면에서 비콘을 발견한 뒤 "비콘 설치 위치 지정"을 눌러 등록할 수 있습니다. 측정 당시 내 위치는 "측정 지점 등록"을 사용하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    final entries = positions.entries.toList()
      ..sort((a, b) {
        // B1 먼저, 같은 층은 좌상단→우하단 순 (y, x 오름차순)
        final fa = a.value.floor.compareTo(b.value.floor);
        if (fa != 0) return fa;
        final ya = a.value.y.compareTo(b.value.y);
        if (ya != 0) return ya;
        return a.value.x.compareTo(b.value.x);
      });
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _BeaconRow(
        beaconId: entries[i].key,
        position: entries[i].value,
        index: i + 1,
        total: entries.length,
      ),
    );
  }
}

class _BeaconRow extends StatelessWidget {
  const _BeaconRow({
    required this.beaconId,
    required this.position,
    required this.index,
    required this.total,
  });
  final String beaconId;
  final BeaconPosition position;
  final int index;
  final int total;

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('비콘 매핑 삭제'),
        content: Text('"$beaconId" 의 좌표 매핑을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppStateProvider>();
    try {
      await app.upsertBeaconPosition(beaconId: beaconId, position: null);
      messenger.showSnackBar(const SnackBar(content: Text('매핑 삭제됨')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('삭제 실패: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _edit(BuildContext context) async {
    final label = _BeaconLabel.parse(beaconId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BeaconPositionEditor(
          beaconId: beaconId,
          beaconName: label.line2.isEmpty
              ? label.kind
              : '${label.kind} · ${label.line2}',
        ),
      ),
    );
  }

  void _copyId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: beaconId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('비콘 ID 복사됨'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _BeaconLabel.parse(beaconId);
    final isB1 = position.floor == 'B1';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.purple.shade100,
          shape: BoxShape.circle,
        ),
        child: Text('$index',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.purple.shade800)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label.kind,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isB1 ? Colors.blue.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isB1 ? Colors.blue.shade300 : Colors.orange.shade300,
              ),
            ),
            child: Text(position.floor,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        isB1 ? Colors.blue.shade800 : Colors.orange.shade800)),
          ),
          const SizedBox(width: 6),
          Text(
            'x ${position.x.toStringAsFixed(1)}%, y ${position.y.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.line1,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (label.line2.isNotEmpty)
              Text(label.line2,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'ID 복사',
            iconSize: 18,
            onPressed: () => _copyId(context),
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: '위치 편집',
            iconSize: 20,
            onPressed: () => _edit(context),
            icon: const Icon(Icons.edit_location_alt),
          ),
          IconButton(
            tooltip: '삭제',
            iconSize: 20,
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

/// 특정 층(B1·B2)의 평면도에 모든 비콘 위치를 핀 오버레이로 표시.
class _BeaconMapView extends StatefulWidget {
  const _BeaconMapView({required this.floor});
  final String floor;

  @override
  State<_BeaconMapView> createState() => _BeaconMapViewState();
}

class _BeaconMapViewState extends State<_BeaconMapView> {
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
    final positions = context.watch<AppStateProvider>().state.beaconPositions;
    final entries =
        positions.entries.where((e) => e.value.floor == widget.floor).toList();
    final ratio = _floorAspectRatio[widget.floor] ?? 1.0;
    final scale = _viewerCtrl.value.getMaxScaleOnAxis();
    final inverse = scale == 0 ? 1.0 : 1.0 / scale;

    return ColoredBox(
      color: Colors.white,
      child: Stack(
        children: [
          Center(
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
                          child: Image.asset(
                            'assets/images/${widget.floor}.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                        for (var i = 0; i < entries.length; i++)
                          _MapPin(
                            index: i + 1,
                            beaconId: entries[i].key,
                            position: entries[i].value,
                            parentSize: Size(w, h),
                            inverseScale: inverse,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (entries.isEmpty)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '이 층에 등록된 비콘이 없습니다.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// === 현위치 추정 ===
///
/// 동작:
/// 1) 연속 BLE 스캔 → 등록된 비콘만 필터
/// 2) 비콘별 최근 3초 이내 RSSI 샘플(최대 5개) 평균
/// 3) 활성 비콘이 가장 많은 층을 현재 층으로 자동 판정
/// 4) RSSI 기반 가중평균으로 (x, y) 추정 — weight = 10^(rssi/10)
class _LivePositionView extends StatefulWidget {
  const _LivePositionView();

  @override
  State<_LivePositionView> createState() => _LivePositionViewState();
}

class _LivePositionViewState extends State<_LivePositionView> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  final Map<String, List<_RssiSample>> _samples = {};
  bool _scanning = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // 30Hz 보다는 살짝 느슨하게 — 250ms 주기로 UI 갱신.
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _refreshTimer?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final sdkInt = defaultTargetPlatform == TargetPlatform.android
          ? await queryAndroidSdkInt()
          : null;
      if (!mounted) return;
      final perms = await bluetoothPermissionsFor(
        defaultTargetPlatform,
        androidSdkInt: sdkInt,
      ).request();
      if (!mounted) return;
      final btOk = bluetoothPermissionsGranted(
        defaultTargetPlatform,
        perms,
        androidSdkInt: sdkInt,
      );
      if (!btOk) {
        setState(() => _error = '권한이 필요합니다. 비콘 스캔 화면에서 권한을 허용해 주세요.');
        return;
      }
      final adapter = await FlutterBluePlus.adapterState
          .where((state) => state != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (adapter != BluetoothAdapterState.on) {
        setState(() => _error = '블루투스를 켜주세요.');
        return;
      }

      _samples.clear();
      unawaited(_scanSub?.cancel());
      _scanSub = FlutterBluePlus.scanResults.listen(_onResults);
      await FlutterBluePlus.startScan(
        androidUsesFineLocation: true,
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 5),
        androidScanMode: AndroidScanMode.lowLatency,
      );
      if (!mounted) return;
      setState(() => _scanning = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '스캔 시작 실패: $e';
        _scanning = false;
      });
    }
  }

  Future<void> _stop() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    if (mounted) setState(() => _scanning = false);
  }

  void _onResults(List<ScanResult> results) {
    final now = DateTime.now();
    for (final r in results) {
      final id = _stableIdOf(r);
      final list = _samples.putIfAbsent(id, () => []);
      list.add(_RssiSample(rssi: r.rssi, time: now));
      // 3초 이내 + 최대 5개 유지
      list.removeWhere((s) => now.difference(s.time).inMilliseconds > 3000);
      while (list.length > 5) {
        list.removeAt(0);
      }
    }
  }

  String _stableIdOf(ScanResult r) {
    final apple = r.advertisementData.manufacturerData[0x004C];
    if (apple != null &&
        apple.length >= 23 &&
        apple[0] == 0x02 &&
        apple[1] == 0x15) {
      final uuid = apple
          .sublist(2, 18)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
      final formatted =
          '${uuid.substring(0, 8)}-${uuid.substring(8, 12)}-${uuid.substring(12, 16)}-${uuid.substring(16, 20)}-${uuid.substring(20, 32)}';
      final major = (apple[18] << 8) | apple[19];
      final minor = (apple[20] << 8) | apple[21];
      return 'ib:$formatted:$major:$minor';
    }
    return 'mac:${r.device.remoteId.str}';
  }

  /// 등록된 비콘만 골라 현위치 추정.
  _EstimatedPosition? _estimate(Map<String, BeaconPosition> registered) {
    // 활성 비콘 = 등록되어 있고 최근 샘플이 있는 비콘.
    final active = <String, double>{}; // beaconId -> avg RSSI
    for (final entry in _samples.entries) {
      final reg = registered[entry.key];
      if (reg == null) continue;
      if (entry.value.isEmpty) continue;
      final avg = entry.value.map((s) => s.rssi).reduce((a, b) => a + b) /
          entry.value.length;
      active[entry.key] = avg;
    }
    if (active.isEmpty) return null;

    // 층 결정: 활성 비콘이 가장 많은 층.
    final floorVotes = <String, int>{};
    for (final id in active.keys) {
      final f = registered[id]!.floor;
      floorVotes[f] = (floorVotes[f] ?? 0) + 1;
    }
    final pickedFloor =
        floorVotes.entries.reduce((a, b) => b.value > a.value ? b : a).key;

    // 가중평균 — weight = 10^(rssi/10) (선형 단위 power)
    double sumX = 0, sumY = 0, sumW = 0;
    var beaconsUsed = 0;
    for (final entry in active.entries) {
      final pos = registered[entry.key]!;
      if (pos.floor != pickedFloor) continue;
      final x = pos.x <= 1.0 ? pos.x * 100 : pos.x;
      final y = pos.y <= 1.0 ? pos.y * 100 : pos.y;
      final weight = math.pow(10, entry.value / 10).toDouble();
      sumX += x * weight;
      sumY += y * weight;
      sumW += weight;
      beaconsUsed++;
    }
    if (sumW == 0 || beaconsUsed == 0) return null;
    return _EstimatedPosition(
      floor: pickedFloor,
      x: sumX / sumW,
      y: sumY / sumW,
      beaconCount: beaconsUsed,
      activeBeaconIds: active.keys.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registered = context.watch<AppStateProvider>().state.beaconPositions;
    if (registered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '먼저 비콘 스캔 → 비콘 설치 위치 지정으로 비콘을 등록해 주세요.\n반복 측정과 공용 위치 추정은 관리자 허브의 "지하 위치 · 신호 지도"를 사용하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    final estimated = _scanning ? _estimate(registered) : null;
    final floor = estimated?.floor ?? (registered.values.first.floor);
    final floorBeacons =
        registered.entries.where((e) => e.value.floor == floor).toList();

    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surfaceContainer,
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                _scanning ? Icons.gps_fixed : Icons.gps_off,
                size: 18,
                color: _scanning ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  estimated != null
                      ? '추정 위치: ${estimated.floor} · x ${estimated.x.toStringAsFixed(1)}%, y ${estimated.y.toStringAsFixed(1)}% (비콘 ${estimated.beaconCount}개)'
                      : _scanning
                          ? '비콘 신호 수집 중…'
                          : '스캔 시작 버튼을 눌러 현위치를 추정합니다.',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.icon(
                onPressed: _scanning ? _stop : _start,
                icon: Icon(_scanning ? Icons.stop : Icons.play_arrow),
                label: Text(_scanning ? '중지' : '스캔 시작'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        Expanded(
          child: _LiveFloorCanvas(
            floor: floor,
            beacons: floorBeacons,
            samples: _samples,
            estimated: estimated,
          ),
        ),
      ],
    );
  }
}

class _RssiSample {
  _RssiSample({required this.rssi, required this.time});
  final int rssi;
  final DateTime time;
}

class _EstimatedPosition {
  _EstimatedPosition({
    required this.floor,
    required this.x,
    required this.y,
    required this.beaconCount,
    required this.activeBeaconIds,
  });
  final String floor;
  final double x; // 0~100 %
  final double y;
  final int beaconCount;
  final List<String> activeBeaconIds;
}

class _LiveFloorCanvas extends StatefulWidget {
  const _LiveFloorCanvas({
    required this.floor,
    required this.beacons,
    required this.samples,
    required this.estimated,
  });
  final String floor;
  final List<MapEntry<String, BeaconPosition>> beacons;
  final Map<String, List<_RssiSample>> samples;
  final _EstimatedPosition? estimated;

  @override
  State<_LiveFloorCanvas> createState() => _LiveFloorCanvasState();
}

class _LiveFloorCanvasState extends State<_LiveFloorCanvas> {
  final TransformationController _viewerCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    _viewerCtrl.addListener(_rebuild);
  }

  @override
  void dispose() {
    _viewerCtrl.removeListener(_rebuild);
    _viewerCtrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _floorAspectRatio[widget.floor] ?? 1.0;
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
                      child: Image.asset(
                        'assets/images/${widget.floor}.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    // 등록된 비콘 핀 (현재 잡힌 비콘은 강조)
                    for (var i = 0; i < widget.beacons.length; i++)
                      _LivePin(
                        index: i + 1,
                        beaconId: widget.beacons[i].key,
                        position: widget.beacons[i].value,
                        parentSize: Size(w, h),
                        inverseScale: inverse,
                        isActive:
                            widget.samples[widget.beacons[i].key]?.isNotEmpty ??
                                false,
                      ),
                    // 추정된 현위치 (파란 원)
                    if (widget.estimated != null)
                      _UserPositionDot(
                        x: widget.estimated!.x,
                        y: widget.estimated!.y,
                        parentSize: Size(w, h),
                        inverseScale: inverse,
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

class _LivePin extends StatelessWidget {
  const _LivePin({
    required this.index,
    required this.beaconId,
    required this.position,
    required this.parentSize,
    required this.inverseScale,
    required this.isActive,
  });
  final int index;
  final String beaconId;
  final BeaconPosition position;
  final Size parentSize;
  final double inverseScale;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final x = position.x <= 1.0 ? position.x * 100 : position.x;
    final y = position.y <= 1.0 ? position.y * 100 : position.y;
    final color = isActive ? Colors.purple.shade600 : Colors.grey.shade500;
    return Positioned(
      left: (x / 100.0) * parentSize.width,
      top: (y / 100.0) * parentSize.height,
      child: Transform.translate(
        offset: const Offset(-12, -12),
        child: Transform.scale(
          scale: inverseScale,
          alignment: Alignment.center,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black38, blurRadius: 2, offset: Offset(0, 1)),
              ],
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserPositionDot extends StatelessWidget {
  const _UserPositionDot({
    required this.x,
    required this.y,
    required this.parentSize,
    required this.inverseScale,
  });
  final double x;
  final double y;
  final Size parentSize;
  final double inverseScale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: (x / 100.0) * parentSize.width,
      top: (y / 100.0) * parentSize.height,
      child: Transform.translate(
        offset: const Offset(-22, -22),
        child: Transform.scale(
          scale: inverseScale,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 펄스 외곽 — 정확도 시각화용 (44x44 외곽 원)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withAlpha(50),
                  border:
                      Border.all(color: Colors.blue.withAlpha(120), width: 1),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.index,
    required this.beaconId,
    required this.position,
    required this.parentSize,
    required this.inverseScale,
  });
  final int index;
  final String beaconId;
  final BeaconPosition position;
  final Size parentSize;
  final double inverseScale;

  @override
  Widget build(BuildContext context) {
    final x = position.x <= 1.0 ? position.x * 100 : position.x;
    final y = position.y <= 1.0 ? position.y * 100 : position.y;
    return Positioned(
      left: (x / 100.0) * parentSize.width,
      top: (y / 100.0) * parentSize.height,
      child: Transform.translate(
        offset: const Offset(-14, -14),
        child: Transform.scale(
          scale: inverseScale,
          alignment: Alignment.center,
          child: Tooltip(
            message: beaconId,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.purple.shade600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black38,
                      blurRadius: 3,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
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
