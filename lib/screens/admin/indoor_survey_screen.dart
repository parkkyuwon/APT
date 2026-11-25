import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/indoor_positioning.dart';
import '../../providers/auth_provider.dart';
import '../../providers/indoor_position_provider.dart';
import '../../widgets/indoor_floor_canvas.dart';
import 'indoor_survey_history_screen.dart';

class IndoorSurveyScreen extends StatefulWidget {
  const IndoorSurveyScreen(
      {required this.accountScope, this.controller, super.key});
  final String accountScope;
  final IndoorPositionProvider? controller;
  @override
  State<IndoorSurveyScreen> createState() => _IndoorSurveyState();
}

class _IndoorSurveyState extends State<IndoorSurveyScreen>
    with WidgetsBindingObserver {
  late final IndoorPositionProvider _controller = widget.controller ??
      IndoorPositionProvider(accountScope: widget.accountScope);
  String _floor = 'B1';
  Offset? _point;
  DateTime? _startedAt;
  Timer? _timer;
  int _remaining = 0;
  bool _starting = false, _saving = false, _complete = false;
  List<BeaconObservation> _captured = [];
  String? _message;
  final _label = TextEditingController();
  bool get _admin => context.read<AuthProvider>().isAdmin;
  bool get _locked => _starting || _remaining > 0 || _complete || _saving;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_cancel());
  }

  Future<void> _start() async {
    if (!_admin || _point == null) return;
    setState(() {
      _starting = true;
      _message = null;
    });
    await _controller.start();
    if (!mounted) return;
    if (!_controller.isScanning) {
      setState(() {
        _starting = false;
        _message = _controller.observer.error ?? '측정을 시작하지 못했습니다.';
      });
      return;
    }
    _startedAt = DateTime.now();
    setState(() {
      _starting = false;
      _remaining = 15;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_controller.isScanning) {
        unawaited(_cancel());
        setState(() => _message = '수신이 중단되어 측정을 취소했습니다.');
      } else if (_remaining <= 1) {
        _timer?.cancel();
        _captured = _controller.observer.observations
            .where((o) => !o.observedAt.isBefore(_startedAt!))
            .toList();
        unawaited(_controller.stop());
        setState(() {
          _remaining = 0;
          _complete = true;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await _controller.stop();
    if (mounted) {
      setState(() {
        _starting = false;
        _remaining = 0;
        _complete = false;
        _captured = [];
      });
    }
  }

  Future<void> _save() async {
    if (!_admin || _captured.isEmpty || _point == null || _startedAt == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final end = _captured
          .map((o) => o.observedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      await _controller.saveSurvey(SurveySession(
        id: 'survey-${DateTime.now().microsecondsSinceEpoch}',
        accountScope: widget.accountScope,
        floor: _floor,
        xPct: _point!.dx,
        yPct: _point!.dy,
        startedAt: _startedAt!,
        endedAt: end.isBefore(_startedAt!) ? _startedAt : end,
        observations: _captured,
        label: _label.text.trim(),
      ));
      if (mounted) {
        setState(() {
          _complete = false;
          _captured = [];
          _message = '측정 기록을 저장했습니다. 공용 배포는 기록 화면에서 진행하세요.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = '저장하지 못했습니다. 측정 결과를 유지했습니다.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _label.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      unawaited(_controller.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isAdmin) {
      return Scaffold(
          appBar: AppBar(title: const Text('신호 측정')),
          body: const Center(child: Text('관리자만 비콘 정보를 등록할 수 있습니다.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('측정 지점 등록'), actions: [
        IconButton(
          tooltip: '측정 기록 · 공용 배포',
          icon: const Icon(Icons.history),
          onPressed: _locked
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      IndoorSurveyHistoryScreen(controller: _controller))),
        )
      ]),
      body: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Column(children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      const Text('측정 당시 내가 서 있는 위치를 지도에서 선택하세요.'),
                      const Text('비콘 설치 좌표는 변경하지 않습니다.',
                          style: TextStyle(color: Colors.black54)),
                      Row(children: [
                        DropdownButton<String>(
                            value: _floor,
                            items: const [
                              DropdownMenuItem(value: 'B1', child: Text('B1')),
                              DropdownMenuItem(value: 'B2', child: Text('B2'))
                            ],
                            onChanged: _locked
                                ? null
                                : (value) => setState(() {
                                      _floor = value!;
                                      _point = null;
                                    })),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextField(
                                controller: _label,
                                enabled: !_locked,
                                decoration: const InputDecoration(
                                    labelText: '기둥·주차면 이름 (선택)'))),
                      ]),
                    ])),
                Expanded(
                    child: IndoorFloorCanvas(
                        floor: _floor,
                        xPct: _point?.dx,
                        yPct: _point?.dy,
                        points: _controller.sessions
                            .where((s) => s.floor == _floor)
                            .map((s) => Offset(s.xPct, s.yPct))
                            .toList(),
                        onPick: _locked
                            ? null
                            : (x, y) => setState(() => _point = Offset(x, y)))),
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      if (_point != null)
                        Text(
                            '$_floor · x ${_point!.dx.toStringAsFixed(1)}%, y ${_point!.dy.toStringAsFixed(1)}%'),
                      if (_message != null) Text(_message!),
                      if (_remaining > 0)
                        Text(
                            '정지 상태로 측정 중 · $_remaining초 남음 · 수신 ${_controller.observer.observations.length}개'),
                      if (_complete)
                        Text(
                            '비콘 ${_captured.map((o) => o.beaconId).toSet().length}개 · 수신 ${_captured.length}개${_captured.isEmpty ? ' · 수신 부족으로 저장할 수 없습니다.' : ''}'),
                      Row(children: [
                        Expanded(
                            child: FilledButton(
                                onPressed:
                                    _point == null || _locked ? null : _start,
                                child:
                                    Text(_starting ? '측정 준비 중' : '15초 측정 시작'))),
                        if (_remaining > 0 || _complete)
                          TextButton(
                              onPressed: _saving ? null : _cancel,
                              child: const Text('취소')),
                        if (_complete)
                          FilledButton(
                              onPressed:
                                  _saving || _captured.isEmpty ? null : _save,
                              child: const Text('측정 저장')),
                      ]),
                    ])),
              ])),
    );
  }
}
