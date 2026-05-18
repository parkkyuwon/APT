import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/privacy.dart';
import '../../models/charger_type.dart';
import '../../models/parking_slot.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/slot_dialog.dart';
import 'slot_filter.dart';

/// [parking-list.html] — 타입별 섹션으로 전체 슬롯을 나열.
class ParkingListScreen extends StatefulWidget {
  const ParkingListScreen({super.key});

  @override
  State<ParkingListScreen> createState() => _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen> {
  SlotFilter _filter = SlotFilter.all;

  Future<void> _onTap(BuildContext context, ParkingSlot slot) async {
    final auth = context.read<AuthProvider>();
    final app = context.read<AppStateProvider>();
    final session = auth.session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
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

    final visibleTypes = <int>[];
    for (var i = 0; i < chargerTypes.length; i++) {
      if (_filter == SlotFilter.all) {
        visibleTypes.add(i);
        continue;
      }
      final all = state.slots[chargerTypes[i].id] ?? const [];
      if (filterSlots(all, state, _filter).isNotEmpty) visibleTypes.add(i);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 주차칸'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: app.isLoading ? null : app.refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<SlotFilter>(
              segments: const [
                ButtonSegment(value: SlotFilter.all, label: Text('전체')),
                ButtonSegment(value: SlotFilter.occupied, label: Text('사용중')),
                ButtonSegment(value: SlotFilter.available, label: Text('미사용')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: app.refresh,
        child: visibleTypes.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('조건에 맞는 주차칸이 없습니다.')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: visibleTypes.length,
                itemBuilder: (_, idx) {
                  final type = chargerTypes[visibleTypes[idx]];
                  final allSlots = state.slots[type.id] ?? const [];
                  final shown = filterSlots(allSlots, state, _filter);
                  var occupied = 0;
                  for (final s in allSlots) {
                    final d = state.slotDetails[s.id];
                    if (d != null && d.isOccupied) occupied++;
                  }
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: ChargerColors.forBadgeClass(type.badgeClass),
                        width: 3,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                type.name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$occupied / ${allSlots.length}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(type.description,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          const Divider(),
                          for (final s in shown) _row(context, s, state),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _row(BuildContext context, ParkingSlot slot, state) {
    final detail = state.slotDetails[slot.id] as SlotDetail? ?? const SlotDetail();
    final session = context.read<AuthProvider>().session;
    final custom = state.slotNames[slot.id] as String?;
    final label = custom != null && custom.isNotEmpty
        ? custom
        : '${chargerTypeById(slot.typeId)?.name ?? slot.typeId} ${slot.id.split('-').last}번';

    String status;
    Color color;
    if (detail.parkingBlocked) {
      status = '주차 불가';
      color = Colors.orange;
    } else if (detail.isOccupied) {
      status = '사용 중';
      color = Colors.blue;
    } else {
      status = '사용 가능';
      color = Colors.green;
    }

    final elapsed = detail.isOccupied ? _elapsedSinceStart(detail.startTime) : null;

    return InkWell(
      onTap: () => _onTap(context, slot),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (detail.isOccupied && detail.vehicleNumber.isNotEmpty)
                    Text(
                      vehicleFor(session, detail.vehicleNumber),
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  if (elapsed != null)
                    Text(
                      '$elapsed 사용 중',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                ],
              ),
            ),
            Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  /// 시작 시각(ISO 8601) 으로부터 현재까지 경과 — "1시간 23분", "30분", "2일 3시간" 등.
  String? _elapsedSinceStart(String startTimeIso) {
    if (startTimeIso.isEmpty) return null;
    final start = DateTime.tryParse(startTimeIso);
    if (start == null) return null;
    final diff = DateTime.now().difference(start);
    if (diff.isNegative) return null;
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);
    if (days > 0) {
      return hours > 0 ? '$days일 $hours시간' : '$days일';
    }
    if (hours > 0) {
      return minutes > 0 ? '$hours시간 $minutes분' : '$hours시간';
    }
    if (minutes > 0) return '$minutes분';
    return '방금';
  }
}
