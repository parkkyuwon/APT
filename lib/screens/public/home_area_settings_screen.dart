import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/indoor_location_bridge.dart';
import '../../models/home_area.dart';
import '../../services/home_area_store.dart';
import '../../widgets/home_area_map.dart';

class HomeAreaSettingsScreen extends StatefulWidget {
  const HomeAreaSettingsScreen(
      {super.key,
      required this.accountScope,
      this.store,
      this.bridge,
      this.serviceEnabled});
  final String accountScope;
  final HomeAreaStore? store;
  final IndoorLocationBridge? bridge;
  final bool Function()? serviceEnabled;
  @override
  State<HomeAreaSettingsScreen> createState() => _HomeAreaSettingsState();
}

class _HomeAreaSettingsState extends State<HomeAreaSettingsScreen>
    with WidgetsBindingObserver {
  late final HomeAreaStore _store = widget.store ?? HomeAreaStore();
  late final IndoorLocationBridge _bridge =
      widget.bridge ?? const IndoorLocationBridge();
  final _latitude = TextEditingController(),
      _longitude = TextEditingController();
  HomeArea? _saved;
  IndoorLocationStatus _status = const IndoorLocationStatus();
  double _radius = 200;
  bool _busy = true;
  bool _pendingActivation = false;
  bool _waitingForSettings = false;
  bool _resumeSettings = false;
  String? _message;
  LatLng? get _center {
    final lat = double.tryParse(_latitude.text),
        lon = double.tryParse(_longitude.text);
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return null;
    }
    return LatLng(lat, lon);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run(() async {
      final area = await _store.load(widget.accountScope);
      if (!mounted) return;
      _saved = area;
      if (area != null) {
        _latitude.text = area.latitude.toString();
        _longitude.text = area.longitude.toString();
        _radius = area.radiusMeters;
      }
      _status = await _bridge.status();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_waitingForSettings) {
      _waitingForSettings = false;
      if (_busy) {
        _resumeSettings = true;
      } else {
        _run(_continueActivation);
      }
    } else if (!_busy) {
      _run(() async {
        _status = await _bridge.status();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (mounted) {
      setState(() {
        _busy = true;
        _message = null;
      });
    }
    try {
      await action();
    } catch (_) {
      // Native exceptions can contain coordinates. Never display/log raw errors.
      _status = const IndoorLocationStatus(reason: 'operationFailed');
      _message = '작업을 완료하지 못했습니다. 저장된 설정은 유지됩니다. 권한과 위치 서비스를 확인해 주세요.';
      _pendingActivation = false;
      _waitingForSettings = false;
    } finally {
      if (mounted) setState(() => _busy = false);
      if (mounted && _resumeSettings) {
        _resumeSettings = false;
        await _run(_continueActivation);
      }
    }
  }

  HomeArea _draft({required bool enabled}) {
    final center = _center;
    if (center == null) throw ArgumentError('Invalid coordinates');
    return HomeArea(
        accountScope: widget.accountScope,
        latitude: center.latitude,
        longitude: center.longitude,
        radiusMeters: _radius,
        revision: (_saved?.revision ?? 0) + 1,
        enabled: enabled);
  }

  Future<void> _save() => _run(() async {
        final area = _draft(enabled: false);
        // Replacing coordinates invalidates the old visit and native registration.
        await _store.save(area);
        await _bridge.disableForAccount(widget.accountScope);
        if (!mounted) return;
        _saved = area;
        _status = await _bridge.status();
        if (!mounted) return;
        _message = '집 반경을 저장했습니다. 자동 안내를 사용하려면 감시를 켜 주세요.';
      });
  Future<void> _toggle(bool enabled) => _run(() async {
        if (!enabled) {
          _pendingActivation = false;
          _waitingForSettings = false;
          if (_saved != null) {
            final area = _saved!.copyWith(enabled: false);
            await _store.save(area);
            if (mounted) _saved = area;
          }
          await _bridge.disableForAccount(widget.accountScope);
          if (!mounted) return;
          _status = await _bridge.status();
          return;
        }
        if (_saved == null) {
          _message = '먼저 집 반경을 저장해 주세요.';
          return;
        }
        if (widget.serviceEnabled?.call() != true) {
          _message = '관리자가 지하 위치 기능을 사용하도록 설정해야 합니다.';
          return;
        }
        final continueWithLocation = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  key: const Key('background-location-disclosure'),
                  title: const Text('백그라운드 위치 사용 안내'),
                  content: const SingleChildScrollView(
                      child: Text(
                          '앱이 닫혀 있거나 사용 중이 아닐 때도 위치 정보를 사용하여 집 주변 도착과 위치 신호 저하를 감지하고 지하 지도 안내 알림을 제공합니다. '
                          '집 반경 설정과 위치 관찰 기록은 기기에 저장되며 공용 비콘 자료로 공유하지 않습니다. '
                          '감시는 이 화면에서 언제든 끌 수 있습니다. 계속하면 위치 및 알림 권한을 차례로 요청합니다.')),
                  actions: [
                    TextButton(
                        key: const Key('background-location-later'),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('나중에')),
                    FilledButton(
                        key: const Key('background-location-continue'),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('계속')),
                  ],
                ));
        if (continueWithLocation != true || !_activationAllowed) return;
        _pendingActivation = true;
        await Permission.locationWhenInUse.request();
        if (!_activationAllowed) return;
        await _bridge.requestPermissions();
        if (!_activationAllowed) return;
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await Permission.locationAlways.request();
          if (!_activationAllowed) return;
          await _bridge.requestBackgroundPermission();
        }
        await _continueActivation();
      });

  Future<void> _continueActivation() async {
    if (!_pendingActivation || !_activationAllowed || _saved == null) {
      _pendingActivation = false;
      if (mounted) _status = await _bridge.status();
      return;
    }
    _status = await _bridge.status();
    if (!_activationAllowed) return;
    if (!_status.supported) {
      _pendingActivation = false;
      _message = '이 기기에서 집 반경 감시를 사용할 수 없습니다.';
      return;
    }
    if (!(await Permission.location.serviceStatus).isEnabled) {
      await _offerSettings('locationServices', '휴대폰 위치 켜기',
          '휴대폰의 위치 기능이 꺼져 있습니다. 위치 설정에서 위치 사용을 켜 주세요.');
      return;
    }
    if (!_activationAllowed) return;
    if (!_status.locationAllowed) {
      await _offerSettings('location', '정확한 위치 허용',
          '앱 설정에서 권한 → 위치를 열고 위치 접근과 정확한 위치 사용을 허용해 주세요.');
      return;
    }
    if (!_status.backgroundAllowed) {
      await _offerSettings('background', '백그라운드 위치 허용',
          '앱이 화면에 없을 때도 집 주변 도착을 감지하려면 앱 설정 → 권한 → 위치에서 항상 허용을 선택해 주세요.');
      return;
    }
    if (!_status.notificationAllowed) {
      await _offerSettings('notifications', '안내 알림 허용',
          '지하 지도 안내를 받으려면 앱 알림과 지하 위치 안내 알림 항목을 허용해 주세요.');
      return;
    }
    _pendingActivation = false;
    final area = _saved!.copyWith(enabled: true);
    // Save before configure, so a persistence failure never leaves an unowned monitor.
    await _store.save(area);
    if (!_activationAllowed) {
      await _revertActivation(area);
      return;
    }
    _saved = area;
    try {
      await _bridge.configure(area);
      if (!_activationAllowed) {
        await _revertActivation(area);
        return;
      }
      _status = await _bridge.status();
      if (!_activationAllowed) {
        await _revertActivation(area);
        return;
      }
      if (!_status.monitoring) _message = '설정은 저장됐지만 감시를 시작하지 못했습니다.';
    } catch (_) {
      await _revertActivation(area);
      if (_activationAllowed) {
        await _bridge.disableForAccount(widget.accountScope);
      }
      rethrow;
    }
  }

  Future<void> _offerSettings(String target, String title, String body) async {
    if (!mounted) return;
    final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                key: const Key('home-settings-dialog'),
                title: Text(title),
                content: Text(body),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('나중에')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('설정으로 이동')),
                ]));
    if (!mounted) return;
    if (open != true || (_pendingActivation && !_activationAllowed)) {
      _pendingActivation = false;
      return;
    }
    _waitingForSettings = _pendingActivation;
    final opened = await _bridge.openSettings(target);
    if (!opened) {
      _waitingForSettings = false;
      _pendingActivation = false;
      _message = '설정 화면을 열지 못했습니다. 휴대폰 설정에서 앱 권한을 확인해 주세요.';
    }
  }

  Future<void> _revertActivation(HomeArea area) async {
    final disabled = area.copyWith(enabled: false);
    await _store.save(disabled);
    if (mounted) _saved = disabled;
  }

  bool get _activationAllowed =>
      mounted && widget.serviceEnabled?.call() == true;
  Future<void> _current() => _run(() async {
        if (!(await Permission.locationWhenInUse.request()).isGranted) {
          await _offerSettings('location', '위치 권한 허용',
              '현재 위치로 집을 지정하려면 앱 설정 → 권한 → 위치에서 위치 사용과 정확한 위치를 허용해 주세요.');
          return;
        }
        if (!mounted) return;
        if (!(await Permission.location.serviceStatus).isEnabled) {
          await _offerSettings('locationServices', '휴대폰 위치 켜기',
              '현재 위치를 확인하려면 휴대폰 위치 설정에서 위치 사용을 켜 주세요.');
          return;
        }
        final fix = await _bridge.currentLocation();
        if (!mounted) return;
        final now = DateTime.now();
        if (fix == null ||
            fix.timestamp.isAfter(now) ||
            now.difference(fix.timestamp) > const Duration(seconds: 15) ||
            fix.accuracy > 50) {
          _message = '정확한 최신 위치를 얻지 못했습니다. 실외에서 다시 시도하거나 좌표를 입력해 주세요.';
          return;
        }
        _latitude.text = fix.latitude.toString();
        _longitude.text = fix.longitude.toString();
      });
  Future<void> _delete() => _run(() async {
        await _store.delete(widget.accountScope);
        await _bridge.disableForAccount(widget.accountScope);
        if (!mounted) return;
        _saved = null;
        _latitude.clear();
        _longitude.clear();
        _radius = 200;
        _status = await _bridge.status();
        _message = '집 설정을 삭제했습니다.';
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('집 반경 · 실내 지도 안내')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              '집 주변에서 실외 위치 품질이 낮아지면 실내 지도 안내 알림을 받을 수 있습니다. 집 좌표는 이 기기의 계정별 보안 저장소에 보관합니다.'),
          const SizedBox(height: 12),
          HomeAreaMap(
              center: _center,
              radiusMeters: _radius,
              onSelected: _busy
                  ? null
                  : (point) => setState(() {
                        _latitude.text = point.latitude.toString();
                        _longitude.text = point.longitude.toString();
                      })),
          const SizedBox(height: 12),
          TextField(
              key: const Key('home-latitude'),
              controller: _latitude,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(labelText: '위도 (-90 ~ 90)'),
              onChanged: (_) => setState(() {})),
          TextField(
              key: const Key('home-longitude'),
              controller: _longitude,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(labelText: '경도 (-180 ~ 180)'),
              onChanged: (_) => setState(() {})),
          TextButton.icon(
              onPressed: _busy ? null : _current,
              icon: const Icon(Icons.my_location),
              label: const Text('현재 위치 사용')),
          Text('반경 ${_radius.round()}m'),
          Slider(
              value: _radius,
              min: 100,
              max: 1000,
              divisions: 18,
              label: '${_radius.round()}m',
              onChanged: _busy ? null : (v) => setState(() => _radius = v)),
          FilledButton(
              onPressed: _busy || _center == null ? null : _save,
              child: const Text('설정 저장')),
          SwitchListTile(
              title: const Text('집 반경 감시'),
              value: _status.monitoring,
              subtitle: Text(_status.monitoring ? '감시 중' : '감시 중지 상태'),
              onChanged: _busy || _saved == null ? null : _toggle),
          Text(
              '위치 권한: ${_status.locationAllowed ? '허용' : '필요'} · 백그라운드: ${_status.backgroundAllowed ? '허용' : '필요'} · 알림: ${_status.notificationAllowed ? '허용' : '필요'}'),
          if (!_status.supported) const Text('현재 환경에서 영역 감시를 사용할 수 없습니다.'),
          if (_status.supported && !_status.monitoring)
            const Text(
                '감시를 시작하려면 위치 서비스와 정확한 위치·항상 허용·알림 권한이 필요합니다. OS의 실행 제한에 따라 알림이 지연될 수 있습니다.'),
          TextButton(
              onPressed: _busy ? null : () => openAppSettings(),
              child: const Text('앱 권한 설정 열기')),
          TextButton(
              onPressed: _busy || _saved == null ? null : _delete,
              child: const Text('집 설정 삭제')),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!)),
        ]),
      );
}
