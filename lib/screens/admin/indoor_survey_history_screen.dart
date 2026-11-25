import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/indoor_positioning.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/indoor_position_provider.dart';
import '../../services/beacon_locator.dart';
import '../../services/indoor_access_controller.dart';
import '../../widgets/indoor_floor_canvas.dart';

class IndoorSurveyHistoryScreen extends StatefulWidget {
  const IndoorSurveyHistoryScreen({required this.controller, super.key});
  final IndoorPositionProvider controller;
  @override
  State<IndoorSurveyHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<IndoorSurveyHistoryScreen> {
  bool _busy = false;
  String? _floorFilter;
  String? _message;
  Future<void> _publish(bool enabled) async {
    if (!context.read<AuthProvider>().isAdmin) return;
    final publication = context.read<IndoorAccessController>().publication;
    if (publication == null) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(enabled ? '공용 위치 정보 배포' : '공용 기능 사용 중지'),
              content: Text(enabled
                  ? '현재 작업 기록 ${widget.controller.sessions.where((s) => s.usable).length}개로 서버 공용 자료를 교체합니다. 이용자는 다음 갱신부터 이 자료를 사용합니다.'
                  : '이용자 앱이 서버의 변경을 확인하면 지하 위치 기능이 중지됩니다. 오프라인 기기에는 즉시 반영되지 않습니다.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('적용'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final success = await publication.publish(
        enabled: enabled,
        surveys: enabled
            ? widget.controller.sessions
            : publication.dataset?.surveys ?? const [],
        beaconPositions: enabled
            ? context.read<AppStateProvider>().state.beaconPositions
            : publication.dataset?.beaconPositions);
    if (mounted) {
      setState(() {
        _busy = false;
        _message = success ? '서버 저장과 공용 버전 갱신을 완료했습니다.' : publication.error;
      });
    }
  }

  Future<void> _import() async {
    final dataset = context.read<IndoorAccessController>().publication?.dataset;
    if (dataset == null || !context.read<AuthProvider>().isAdmin) return;
    setState(() => _busy = true);
    try {
      for (final survey in dataset.surveys) {
        await widget.controller.saveSurvey(SurveySession.fromJson({
          ...survey.toJson(),
          'accountScope': widget.controller.accountScope,
        }));
      }
      if (mounted) {
        setState(() => _message = '서버 자료를 작업 기록으로 불러왔습니다. 수정 후 다시 배포하세요.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = '서버 자료를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exclude(SurveySession s, bool excluded) async {
    try {
      await widget.controller.excludeSurvey(s.id, excluded);
    } catch (_) {
      if (mounted) setState(() => _message = '기록 변경을 저장하지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isAdmin) {
      return const Scaffold(body: Center(child: Text('관리자 전용 기능입니다.')));
    }
    final publication = context.watch<IndoorAccessController>().publication;
    return Scaffold(
        appBar: AppBar(title: const Text('측정 기록 · 공용 배포')),
        body: AnimatedBuilder(
            animation: widget.controller,
            builder: (_, __) =>
                ListView(padding: const EdgeInsets.all(12), children: [
                  Text(
                      '공용 기능: ${publication?.dataset?.enabled == true ? '사용 중' : '사용 안 함'} · 서버 버전 ${publication?.dataset?.revision ?? '확인 필요'}'),
                  if (publication?.error != null) Text(publication!.error!),
                  if (_message != null) Text(_message!),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                        onPressed: _busy ? null : publication?.refresh,
                        child: const Text('서버 갱신 확인')),
                    OutlinedButton(
                        onPressed: _busy || publication?.dataset == null
                            ? null
                            : _import,
                        child: const Text('서버 측정 불러오기')),
                    FilledButton(
                        onPressed: _busy ||
                                publication?.dataset == null ||
                                !widget.controller.sessions.any((s) => s.usable)
                            ? null
                            : () => _publish(true),
                        child: const Text('배포 · 이용자 사용 켜기')),
                    OutlinedButton(
                        onPressed: _busy || publication?.dataset == null
                            ? null
                            : () => _publish(false),
                        child: const Text('이용자 사용 끄기')),
                  ]),
                  const Text(
                      '로컬 작업 기록은 관리자 기기에 보관됩니다. 배포하면 이용자가 공유받습니다. 제외/수정/삭제는 다시 배포해야 반영됩니다.'),
                  const Divider(),
                  Wrap(spacing: 8, children: [
                    ChoiceChip(
                        label: const Text('전체 층'),
                        selected: _floorFilter == null,
                        onSelected: (_) => setState(() => _floorFilter = null)),
                    for (final floor in ['B1', 'B2'])
                      ChoiceChip(
                          label: Text(floor),
                          selected: _floorFilter == floor,
                          onSelected: (_) =>
                              setState(() => _floorFilter = floor)),
                  ]),
                  const Text('층별로 기록을 구분합니다. 공용 배포는 B1/B2 전체 작업 기록에 적용됩니다.'),
                  if (widget.controller.loading)
                    const LinearProgressIndicator(),
                  if (widget.controller.error != null)
                    Text(widget.controller.error!),
                  for (final s in widget.controller.sessions.where(
                      (s) => _floorFilter == null || s.floor == _floorFilter))
                    ListTile(
                      title: Text(
                          '${s.floor} · ${s.label.isEmpty ? s.id : s.label}${s.excluded ? ' · 제외됨' : ''}'),
                      subtitle: Text(
                          'x ${s.xPct.toStringAsFixed(1)}%, y ${s.yPct.toStringAsFixed(1)}% · 비콘 ${s.observations.map((o) => o.beaconId).toSet().length}개'),
                      trailing: IconButton(
                          tooltip: s.excluded ? '학습에 포함' : '학습에서 제외',
                          onPressed:
                              _busy ? null : () => _exclude(s, !s.excluded),
                          icon: Icon(s.excluded
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline)),
                    ),
                  const Divider(),
                  const Text('비콘 위치 후보 · 도식화의 신호가 강한 구역이며 설치 위치 확정값이 아닙니다.'),
                  for (final id in widget.controller.sessions
                      .where((s) =>
                          s.usable &&
                          (_floorFilter == null || s.floor == _floorFilter))
                      .expand((s) => s.observations)
                      .map((o) => o.beaconId)
                      .toSet())
                    _CandidateTile(
                        id: id,
                        sessions: widget.controller.sessions
                            .where((s) =>
                                _floorFilter == null || s.floor == _floorFilter)
                            .toList()),
                ])));
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.id, required this.sessions});
  final String id;
  final List<SurveySession> sessions;
  @override
  Widget build(BuildContext context) {
    final candidate = const BeaconLocator().estimate(id, sessions);
    return ListTile(
        title: Text(id),
        subtitle: Text(candidate == null
            ? '서로 다른 위치에서 추가 측정이 필요합니다.'
            : '${candidate.floor} · 신호 후보 구역 · 측정점 ${candidate.pointCount}개'),
        onTap: candidate == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('비콘 위치 후보')),
                      body: Column(children: [
                        const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                                '설치 위치로 확정하지 않은 신호 후보 구역입니다. 현장 확인과 지도 축척 보정이 필요합니다.')),
                        Expanded(
                            child: IndoorFloorCanvas(
                                floor: candidate.floor,
                                xPct: candidate.xPct,
                                yPct: candidate.yPct,
                                markerColor: Colors.orange))
                      ]),
                    ))));
  }
}
