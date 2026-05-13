import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';
import '../../models/charger_type.dart';
import '../../providers/app_state_provider.dart';

/// [console_operations_k9r2m4x.html] — 운영 설정 (준비중 토글, 공지, 충전기 수량).
class ConsoleOperations extends StatefulWidget {
  const ConsoleOperations({super.key});

  @override
  State<ConsoleOperations> createState() => _ConsoleOperationsState();
}

class _ConsoleOperationsState extends State<ConsoleOperations> {
  late TextEditingController _noticeCtrl;
  late TextEditingController _autoCloseCtrl;
  late TextEditingController _chatRetentionCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noticeCtrl = TextEditingController();
    _autoCloseCtrl = TextEditingController();
    _chatRetentionCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = context.read<AppStateProvider>();
    await app.refresh();
    if (!mounted) return;
    final s = app.state;
    _noticeCtrl.text = s.popupNotice.content;
    _autoCloseCtrl.text = s.popupNotice.autoCloseSeconds.toString();
    _chatRetentionCtrl.text = s.chatRetentionDays.toString();
    setState(() {});
  }

  @override
  void dispose() {
    _noticeCtrl.dispose();
    _autoCloseCtrl.dispose();
    _chatRetentionCtrl.dispose();
    super.dispose();
  }

  Future<void> _patchState(Map<String, dynamic> overrides) async {
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppStateProvider>();
    setState(() => _saving = true);
    try {
      final payload = _currentPayload(app.state);
      payload.addAll(overrides);
      await app.saveFullState(payload);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('실패: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _currentPayload(AppState s) {
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
      'slotMapPositions': s.slotMapPositions.map((k, v) => MapEntry(k, v.toJson())),
      'beaconMappings': Map<String, String>.from(s.beaconMappings),
      'beaconPositions':
          s.beaconPositions.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  Future<void> _updateCount(String typeId, int delta) async {
    final app = context.read<AppStateProvider>();
    final payload = _currentPayload(app.state);
    final counts = Map<String, int>.from(payload['counts'] as Map);
    final current = counts[typeId] ?? 0;
    final next = (current + delta).clamp(0, 999);
    counts[typeId] = next;
    payload['counts'] = counts;

    // 슬롯 배열 재생성 + 사라진 슬롯의 detail 제거
    final slotsMap = Map<String, dynamic>.from(payload['slots'] as Map);
    slotsMap[typeId] = List.generate(
      next,
      (i) => {'id': '$typeId-${i + 1}', 'typeId': typeId},
    );
    payload['slots'] = slotsMap;

    final slotDetails = Map<String, dynamic>.from(payload['slotDetails'] as Map);
    slotDetails.removeWhere((key, _) {
      if (!key.startsWith('$typeId-')) return false;
      final n = int.tryParse(key.split('-').last) ?? 0;
      return n > next;
    });
    payload['slotDetails'] = slotDetails;

    await _patchState(payload);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final s = app.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('운영 설정'),
        actions: [
          IconButton(onPressed: _saving ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: SwitchListTile(
              value: s.maintenanceMode,
              onChanged: _saving
                  ? null
                  : (v) => _patchState({'maintenanceMode': v}),
              title: const Text('준비중 모드',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('활성화 시 사용자 화면에 안내 오버레이가 표시됩니다.'),
            ),
          ),
          Card(
            child: SwitchListTile(
              value: s.adEnabled,
              onChanged: _saving ? null : (v) => _patchState({'adEnabled': v}),
              title: const Text('광고 노출', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('공개 화면 AdSense 광고 노출 여부.'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('공지사항',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: s.popupNotice.enabled,
                    onChanged: _saving
                        ? null
                        : (v) => _patchState({
                              'popupNotice': <String, dynamic>{
                                'enabled': v,
                                'content': _noticeCtrl.text,
                                'autoCloseSeconds':
                                    int.tryParse(_autoCloseCtrl.text) ?? 0,
                              },
                            }),
                    title: const Text('공지 팝업 활성화'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextField(
                    controller: _noticeCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '공지 내용',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _autoCloseCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '자동 닫기(초)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving
                              ? null
                              : () => _patchState({
                                    'popupNotice': <String, dynamic>{
                                      'enabled': s.popupNotice.enabled,
                                      'content': _noticeCtrl.text,
                                      'autoCloseSeconds':
                                          int.tryParse(_autoCloseCtrl.text) ?? 0,
                                    },
                                  }),
                          child: const Text('공지 저장'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('채팅 보존 기간',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatRetentionCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '일수',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () => _patchState({
                                  'chatRetentionDays':
                                      int.tryParse(_chatRetentionCtrl.text) ?? 30,
                                }),
                        child: const Text('저장'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('충전기 수량',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  for (final t in chargerTypes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(t.description,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black54)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _saving ? null : () => _updateCount(t.id, -1),
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${s.counts[t.id] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _saving ? null : () => _updateCount(t.id, 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
