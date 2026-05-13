import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';
import '../../providers/app_state_provider.dart';
import 'beacon_position_editor.dart';

/// 관리자 콘솔 — BLE 비콘 스캔.
///
/// 내 주변에서 광고 중인 BLE 기기·비콘을 실시간으로 보여주고
/// 종류(iBeacon / Eddystone / 기타) 와 RSSI(신호 세기) 를 함께 표시.
class ConsoleBeaconScan extends StatefulWidget {
  const ConsoleBeaconScan({super.key});

  @override
  State<ConsoleBeaconScan> createState() => _ConsoleBeaconScanState();
}

class _ConsoleBeaconScanState extends State<ConsoleBeaconScan> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  final Map<String, ScanResult> _devices = <String, ScanResult>{};
  bool _isScanning = false;
  String? _error;
  bool _bluetoothOn = false;

  @override
  void initState() {
    super.initState();
    _isScanningSub = FlutterBluePlus.isScanning.listen((s) {
      if (!mounted) return;
      setState(() => _isScanning = s);
    });
    _checkBluetoothState();
  }

  Future<void> _checkBluetoothState() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (!mounted) return;
      setState(() => _bluetoothOn = state == BluetoothAdapterState.on);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<bool> _ensurePermissions() async {
    // Android 12+ 는 BLUETOOTH_SCAN(=근처 기기), 이하 버전은 LOCATION + BLUETOOTH 그룹 필요.
    final required = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    // 시스템 설정에 권한 항목이 노출되려면 앱이 한 번이라도 명시적으로 요청한 이력이
    // 필요한 기기가 있다. 영구 거부 검사 전에 우선 request() 를 강제 호출해
    // 항목이 노출되도록 한다.
    final results = await required.request();

    if (!mounted) return false;

    final btScan = results[Permission.bluetoothScan];
    final btConnect = results[Permission.bluetoothConnect];
    final loc = results[Permission.locationWhenInUse];

    bool isOk(PermissionStatus? s) =>
        s != null && (s.isGranted || s.isLimited || s.isProvisional);

    // Android 12+ 는 BLUETOOTH_SCAN 묶음(=근처 기기) 만 허용돼 있으면 충분.
    // permission_handler 가 OS 가 권한을 묵음 grant 한 경우 status 가 denied/restricted
    // 로 돌아올 수 있어 isOk 가 false 인 경우라도 실제 OS 단에서 허용된 상태일 수 있다.
    // 그래서 BT 권한만 통과되면 곧장 스캔 시도로 넘어가고, 실패 시 startScan 의
    // catch 에서 다이얼로그를 띄우는 방식으로 안전하게 처리한다.
    if (isOk(btScan) && isOk(btConnect)) {
      setState(() => _error = null);
      return true;
    }

    // Android 11 이하 폴백: 위치 권한이 있으면 legacy BLE 스캔 가능.
    if (isOk(loc) && (isOk(btScan) || btScan == null)) {
      setState(() => _error = null);
      return true;
    }

    // 권한 부족 — 무엇이 빠졌는지 사용자에게 알려준다.
    final missing = <String>[];
    if (!isOk(btScan) || !isOk(btConnect)) {
      missing.add('근처 기기 (블루투스 검색)');
    }
    if (!isOk(loc) && !isOk(btScan)) {
      missing.add('위치 (Android 11 이하만 필요)');
    }
    return _promptOpenSettings(missing);
  }

  Future<bool> _promptOpenSettings(List<String> missing) async {
    if (!mounted) return false;
    final list = missing.isEmpty ? '블루투스/위치' : missing.join(', ');
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('권한 필요'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$list 권한이 필요합니다.', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('"설정 열기" 를 누른 뒤 시스템 화면에서 다음 순서로 허용해 주세요:'),
              const SizedBox(height: 8),
              const Text('① "권한 (Permissions)" 메뉴 탭'),
              const Text('② "근처 기기 (Nearby devices)" → "허용"'),
              const Text('   • Android 12+ 의 블루투스 검색 권한 묶음입니다.'),
              const Text('③ Android 11 이하 기기는 "위치" 권한도 함께 허용'),
              const SizedBox(height: 8),
              const Text('※ Samsung 기기는 권한 메뉴에서 "더보기 / 모두 보기" 를 눌러야 항목이 노출되기도 합니다.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.settings),
            label: const Text('설정 열기'),
          ),
        ],
      ),
    );
    if (open == true) {
      await openAppSettings();
    }
    if (mounted) {
      setState(() => _error = '권한 허용 후 다시 "스캔 시작" 을 눌러주세요.');
    }
    return false;
  }

  Future<void> _startScan() async {
    setState(() => _error = null);
    final granted = await _ensurePermissions();
    if (!granted) return;
    if (!await FlutterBluePlus.isSupported) {
      setState(() => _error = '이 기기는 BLE 를 지원하지 않습니다.');
      return;
    }
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      setState(() {
        _error = '블루투스가 꺼져 있습니다. 시스템 설정에서 켜주세요.';
        _bluetoothOn = false;
      });
      try {
        unawaited(FlutterBluePlus.turnOn());
      } catch (_) {}
      return;
    }

    _devices.clear();
    setState(() {});
    unawaited(_scanSub?.cancel());
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      var changed = false;
      for (final r in results) {
        final id = r.device.remoteId.str;
        final prev = _devices[id];
        if (prev == null || prev.rssi != r.rssi || prev.timeStamp != r.timeStamp) {
          _devices[id] = r;
          changed = true;
        }
      }
      if (changed) setState(() {});
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '스캔 시작 실패: $e');
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// iBeacon: manufacturer data 가 Apple(0x004C) + 첫 두 바이트 0x02 0x15.
  /// Eddystone: serviceUuid 가 0xFEAA.
  String _signalKind(ScanResult r) {
    final ad = r.advertisementData;
    if (ad.serviceUuids.any((u) => u.str.toLowerCase().startsWith('feaa'))) {
      return 'Eddystone';
    }
    if (_parseIBeacon(r) != null) return 'iBeacon';
    if (ad.manufacturerData.isNotEmpty) return 'BLE (Manufacturer)';
    if (ad.serviceUuids.isNotEmpty) return 'BLE (Service)';
    return 'BLE';
  }

  /// iBeacon manufacturer data (Apple 0x004C):
  /// [0x02, 0x15, UUID(16), Major(2 BE), Minor(2 BE), TxPower(1 signed)]
  /// = 23 bytes total after the company ID.
  _IBeaconData? _parseIBeacon(ScanResult r) {
    final apple = r.advertisementData.manufacturerData[0x004C];
    if (apple == null || apple.length < 23) return null;
    if (apple[0] != 0x02 || apple[1] != 0x15) return null;
    final uuidBytes = apple.sublist(2, 18);
    final uuid = _formatUuid(uuidBytes);
    final major = (apple[18] << 8) | apple[19];
    final minor = (apple[20] << 8) | apple[21];
    final txByte = apple[22];
    final txPower = txByte > 127 ? txByte - 256 : txByte;
    return _IBeaconData(uuid: uuid, major: major, minor: minor, txPower: txPower);
  }

  String _formatUuid(List<int> bytes) {
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// 매핑·식별용 안정 키. MAC 은 OS 가 주기적으로 회전시키므로
  /// iBeacon 인 경우 UUID:Major:Minor 를 우선 사용.
  String _stableId(ScanResult r) {
    final ib = _parseIBeacon(r);
    if (ib != null) return 'ib:${ib.uuid}:${ib.major}:${ib.minor}';
    return 'mac:${r.device.remoteId.str}';
  }

  String _name(ScanResult r) {
    final n = r.advertisementData.advName.isNotEmpty
        ? r.advertisementData.advName
        : r.device.platformName;
    return n.isEmpty ? '(이름 없음)' : n;
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -60) return Colors.green.shade700;
    if (rssi >= -75) return Colors.orange.shade700;
    return Colors.red.shade400;
  }

  String _bytesToHex(List<int> bytes, {int max = 20}) {
    final truncated = bytes.length > max ? bytes.sublist(0, max) : bytes;
    final hex = truncated
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    return bytes.length > max ? '$hex … (+${bytes.length - max}B)' : hex;
  }

  /// 지도 위치 편집 화면으로 이동. 저장 결과는 AppStateProvider 가 직접 반영.
  Future<void> _openPositionEditor(ScanResult r) async {
    final beaconId = _stableId(r);
    final name = _name(r);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BeaconPositionEditor(
          beaconId: beaconId,
          beaconName: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final positions =
        context.watch<AppStateProvider>().state.beaconPositions;
    final sorted = _devices.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE 비콘 스캔'),
        actions: [
          IconButton(
            tooltip: '초기화',
            onPressed: () => setState(_devices.clear),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(_bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                    size: 18, color: _bluetoothOn ? Colors.blue : Colors.grey),
                const SizedBox(width: 6),
                Text(_bluetoothOn ? '블루투스 ON' : '블루투스 OFF',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const Spacer(),
                Text(_isScanning ? '스캔 중…' : '대기',
                    style: TextStyle(
                        fontSize: 12,
                        color: _isScanning ? Colors.blue : Colors.black54)),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: Icon(_isScanning ? Icons.stop : Icons.search),
                  label: Text(_isScanning ? '중지' : '스캔 시작'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('감지된 기기 ${sorted.length}개',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('RSSI 높을수록 가까움',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      _isScanning ? '주변 신호 탐색 중…' : '스캔 시작 버튼을 눌러주세요',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = sorted[i];
                      final stableId = _stableId(r);
                      final iBeacon = _parseIBeacon(r);
                      final position = positions[stableId];
                      return _DeviceTile(
                        result: r,
                        kind: _signalKind(r),
                        name: _name(r),
                        rssiColor: _rssiColor(r.rssi),
                        manufacturerHex: r
                                .advertisementData
                                .manufacturerData
                                .entries
                                .isEmpty
                            ? null
                            : _bytesToHex(r.advertisementData.manufacturerData.values.first),
                        iBeacon: iBeacon,
                        stableId: stableId,
                        position: position,
                        onMap: () => _openPositionEditor(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// iBeacon 광고 패킷 파싱 결과.
class _IBeaconData {
  _IBeaconData({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.txPower,
  });
  final String uuid; // 8-4-4-4-12 형식 (대문자)
  final int major;
  final int minor;
  final int txPower; // 1m 거리 기준 RSSI 보정값 (signed, dBm)
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.result,
    required this.kind,
    required this.name,
    required this.rssiColor,
    required this.manufacturerHex,
    required this.iBeacon,
    required this.stableId,
    required this.position,
    required this.onMap,
  });

  final ScanResult result;
  final String kind;
  final String name;
  final Color rssiColor;
  final String? manufacturerHex;
  final _IBeaconData? iBeacon;
  final String stableId;
  final BeaconPosition? position;
  final VoidCallback onMap;

  Widget _kv(String key, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(key,
                style: const TextStyle(
                    fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.black87,
                fontFamily: monospace ? 'monospace' : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = result.advertisementData;
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: rssiColor.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${result.rssi} dBm',
                style: TextStyle(
                    fontSize: 11, color: rssiColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(kind,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(result.device.remoteId.str,
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            if (iBeacon != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('UUID', iBeacon!.uuid, monospace: true),
                    Row(
                      children: [
                        Expanded(child: _kv('Major', '${iBeacon!.major}')),
                        Expanded(child: _kv('Minor', '${iBeacon!.minor}')),
                        Expanded(child: _kv('Tx', '${iBeacon!.txPower}dBm')),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (ad.serviceUuids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Services: ${ad.serviceUuids.map((u) => u.str).join(", ")}',
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                      overflow: TextOverflow.ellipsis),
                ),
              if (manufacturerHex != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Mfr: $manufacturerHex',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.black54, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  if (position != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place, size: 12, color: Colors.purple),
                          const SizedBox(width: 3),
                          Text(
                            '${position!.floor} ${position!.x.toStringAsFixed(1)}%, ${position!.y.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.purple.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: onMap,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('변경', style: TextStyle(fontSize: 11)),
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: onMap,
                      icon: const Icon(Icons.place_outlined, size: 14),
                      label: const Text('지도에 위치 지정', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
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

