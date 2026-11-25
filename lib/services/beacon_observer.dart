import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/bluetooth_permissions.dart';
import '../models/indoor_positioning.dart';

BeaconObservation? parseIBeaconAdvertisement(List<int> data,
    {required int rssi, required DateTime observedAt}) {
  if (data.length < 23 ||
      data[0] != 2 ||
      data[1] != 21 ||
      data.any((b) => b < 0 || b > 255) ||
      rssi >= 0 ||
      rssi < -127) {
    return null;
  }
  final hex = data
      .sublist(2, 18)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  final uuid =
      '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  final power = data[22] > 127 ? data[22] - 256 : data[22];
  return BeaconObservation(
      beaconId:
          'ib:$uuid:${data[18] * 256 + data[19]}:${data[20] * 256 + data[21]}',
      rssi: rssi,
      observedAt: observedAt,
      measuredPower: power < 0 && power > -128 ? power : null);
}

/// Platform boundary; timestamps in packets must be the advertisement timestamps.
abstract class BeaconScanSource {
  Stream<List<BeaconObservation>> get packets;
  Stream<bool> get available;
  Future<void> prepare();
  Future<void> start();
  Future<void> stop();
}

class _FlutterBeaconScanSource implements BeaconScanSource {
  bool _started = false;
  @override
  Stream<List<BeaconObservation>> get packets =>
      FlutterBluePlus.onScanResults.map((results) => results
          .map((r) {
            final data = r.advertisementData.manufacturerData[0x004c];
            return data == null
                ? null
                : parseIBeaconAdvertisement(data,
                    rssi: r.rssi, observedAt: r.timeStamp);
          })
          .whereType<BeaconObservation>()
          .toList());
  @override
  Stream<bool> get available => FlutterBluePlus.adapterState
      .where((s) => s != BluetoothAdapterState.unknown)
      .map((s) => s == BluetoothAdapterState.on);
  @override
  Future<void> prepare() async {
    if (FlutterBluePlus.isScanningNow) {
      throw StateError('진행 중인 비콘 스캔을 먼저 종료해 주세요.');
    }
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      throw StateError('Android/iOS 기기에서 Bluetooth를 사용해 주세요.');
    }
    final sdk =
        platform == TargetPlatform.android ? await queryAndroidSdkInt() : null;
    final permissions =
        await bluetoothPermissionsFor(platform, androidSdkInt: sdk).request();
    if (!bluetoothPermissionsGranted(platform, permissions,
        androidSdkInt: sdk)) {
      throw StateError('Bluetooth 및 위치 권한이 필요합니다.');
    }
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('Bluetooth LE를 지원하지 않습니다.');
    }
    final state = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 10));
    if (state != BluetoothAdapterState.on) {
      throw StateError('Bluetooth가 꺼져 있습니다.');
    }
  }

  @override
  Future<void> start() async {
    _started = true;
    await FlutterBluePlus.startScan(
        androidUsesFineLocation: true,
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: true);
    // A cancellation can stop the pending native request before it completes.
    // Mark a late success again so the observer's cancellation cleanup stops it.
    _started = true;
  }

  @override
  Future<void> stop() async {
    if (_started) {
      await FlutterBluePlus.stopScan();
      _started = false;
    }
  }
}

/// Foreground observation session. Refuses to stop scans owned by another screen.
class BeaconObserver extends ChangeNotifier {
  static BeaconObserver? _scanOwner;
  final DateTime Function() clock;
  final BeaconScanSource _source;
  final List<BeaconObservation> _observations = [];
  final Map<String, DateTime> _lastSeen = {};
  StreamSubscription<List<BeaconObservation>>? _subscription;
  StreamSubscription<bool>? _adapterSubscription;
  Timer? _expiry;
  bool _disposed = false, _starting = false;
  int _generation = 0;
  bool isScanning = false;
  String? error;
  BeaconObserver({DateTime Function()? clock, BeaconScanSource? source})
      : clock = clock ?? DateTime.now,
        _source = source ?? _FlutterBeaconScanSource();
  List<BeaconObservation> get observations => List.unmodifiable(_observations);
  List<BeaconObservation> recent([DateTime? now]) {
    final time = now ?? clock();
    return _observations
        .where((o) =>
            !o.observedAt.isAfter(time) &&
            time.difference(o.observedAt) < const Duration(seconds: 5))
        .toList();
  }

  void addObservations(Iterable<BeaconObservation> packets) {
    if (_disposed) return;
    var changed = false;
    final now = clock();
    for (final o in packets) {
      if (o.observedAt.isAfter(now) ||
          now.difference(o.observedAt) >= const Duration(seconds: 5)) {
        continue;
      }
      final last = _lastSeen[o.beaconId];
      if (last != null && !o.observedAt.isAfter(last)) continue;
      _lastSeen[o.beaconId] = o.observedAt;
      _observations.add(o);
      changed = true;
    }
    if (_observations.length > 20000) {
      _observations.removeRange(0, _observations.length - 20000);
    }
    if (changed) notifyListeners();
  }

  Future<void> start() async {
    if (_disposed || _starting || isScanning) return;
    _starting = true;
    final generation = ++_generation;
    error = null;
    try {
      if (_scanOwner != null && _scanOwner != this) {
        throw StateError('다른 실내 측정이 진행 중입니다.');
      }
      _scanOwner = this;
      await _source.prepare();
      if (_disposed || generation != _generation) return;
      _observations.clear();
      _lastSeen.clear();
      _subscription =
          _source.packets.listen(addObservations, onError: (Object e) {
        error = 'Bluetooth 수신 오류';
        unawaited(stop());
      });
      _adapterSubscription = _source.available.listen((available) {
        if (!available) {
          error = 'Bluetooth 연결이 중단되었습니다.';
          unawaited(stop());
        }
      });
      await _source.start();
      if (_disposed || generation != _generation) {
        await stop();
        return;
      }
      isScanning = true;
      _expiry = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_disposed) notifyListeners();
      });
    } catch (e) {
      error = e.toString();
      await stop();
    } finally {
      _starting = false;
      if (_disposed || generation != _generation) await stop();
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> stop() async {
    ++_generation;
    _expiry?.cancel();
    _expiry = null;
    await _subscription?.cancel();
    _subscription = null;
    await _adapterSubscription?.cancel();
    _adapterSubscription = null;
    if (_scanOwner == this) {
      // Keep ownership until stop completes, preventing a new observer racing it.
      try {
        await _source.stop();
      } catch (_) {
      } finally {
        if (!_starting) _scanOwner = null;
      }
    }
    isScanning = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
