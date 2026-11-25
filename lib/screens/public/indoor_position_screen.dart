import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/indoor_positioning.dart';
import '../../services/beacon_observer.dart';
import '../../services/fingerprint_positioner.dart';
import '../../services/indoor_access_controller.dart';
import '../../widgets/indoor_floor_canvas.dart';

class IndoorPositionScreen extends StatefulWidget {
  const IndoorPositionScreen({super.key});
  @override
  State<IndoorPositionScreen> createState() => _IndoorPositionState();
}

class _IndoorPositionState extends State<IndoorPositionScreen>
    with WidgetsBindingObserver {
  final _observer = BeaconObserver();
  IndoorAccessController? _access;
  PositionEstimate? _position;
  bool _starting = false;
  String _floor = 'B1';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _observer.addListener(_update);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final access = context.read<IndoorAccessController>();
    if (_access != access) {
      _access?.removeListener(_update);
      _access = access;
      access.addListener(_update);
    }
  }

  void _update() {
    if (!mounted) return;
    final dataset = _access?.publication?.dataset;
    if (dataset?.usable != true) {
      if (_observer.isScanning) unawaited(_observer.stop());
      if (mounted) setState(() => _position = null);
      return;
    }
    final estimate = _observer.isScanning
        ? const FingerprintPositioner()
            .estimate(dataset!.surveys, _observer.recent(), now: DateTime.now())
        : null;
    setState(() {
      _position = estimate;
      if (estimate != null) _floor = estimate.floor;
    });
  }

  Future<void> _start() async {
    if (_access?.publication?.available != true) return;
    setState(() => _starting = true);
    await _observer.start();
    if (mounted) setState(() => _starting = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_observer.stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _access?.removeListener(_update);
    _observer.removeListener(_update);
    _observer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<IndoorAccessController>();
    final publication = access.publication;
    final available = publication?.available == true;
    return Scaffold(
        appBar: AppBar(title: const Text('지하 내 위치'), actions: [
          IconButton(
              tooltip: '공용 정보 갱신',
              onPressed:
                  publication?.loading == true ? null : publication?.refresh,
              icon: const Icon(Icons.refresh)),
        ]),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text(available
                    ? '관리자 공용 지도 · 버전 ${publication!.dataset!.revision}${publication.offline ? ' · 저장된 자료 사용' : ''}'
                    : publication?.loading == true
                        ? '관리자 등록 정보를 확인하고 있습니다.'
                        : '관리자가 사용 설정과 신호 지도를 배포해야 합니다.'),
                if (publication?.error != null) Text(publication!.error!),
                const Text('지하에서는 휴대폰에 저장한 신호 지도를 사용합니다.'),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final floor in ['B1', 'B2'])
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                            label: Text(floor),
                            selected: _floor == floor,
                            onSelected: (_) => setState(() => _floor = floor))),
                ]),
              ])),
          Expanded(
              child: IndoorFloorCanvas(
                  floor: _floor,
                  xPct: _position?.floor == _floor ? _position?.xPct : null,
                  yPct: _position?.floor == _floor ? _position?.yPct : null)),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text(_position == null
                    ? (_observer.isScanning
                        ? '신호 수집 중 · 위치/층을 판단할 자료가 부족합니다.'
                        : '위치 찾기를 시작해 주세요.')
                    : '${_position!.floor} · 비콘 ${_position!.beaconCount}개 · ${_position!.quality == PositionQuality.low ? '후보 구역' : '추정 위치'}'),
                if (_position != null)
                  const Text('정확한 거리와 위치는 현장 검증 전입니다.',
                      style: TextStyle(color: Colors.black54)),
                if (_observer.error != null) Text(_observer.error!),
                FilledButton.icon(
                    onPressed: _starting
                        ? null
                        : _observer.isScanning
                            ? _observer.stop
                            : available
                                ? _start
                                : null,
                    icon: Icon(
                        _observer.isScanning ? Icons.stop : Icons.my_location),
                    label: Text(_starting
                        ? '준비 중'
                        : _observer.isScanning
                            ? '위치 찾기 중지'
                            : '내 위치 찾기')),
              ])),
        ]));
  }
}
