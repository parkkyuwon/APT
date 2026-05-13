import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/charger_type.dart';
import '../../models/parking_slot.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/slot_dialog.dart';

/// [console_parking_k9r2m4x.html] — 관리자용 전체 슬롯 직접 편집.
///
/// 일반 사용자 home_screen 과 유사하나 관리자는 모든 슬롯을 편집할 수 있다.
class ConsoleParking extends StatefulWidget {
  const ConsoleParking({super.key});

  @override
  State<ConsoleParking> createState() => _ConsoleParkingState();
}

class _ConsoleParkingState extends State<ConsoleParking> {
  Future<void> _editSlot(ParkingSlot slot) async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<AuthProvider>().session;
    final app = context.read<AppStateProvider>();
    if (session == null) return;
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
      messenger.showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final state = app.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('주차 정보 관리'),
        actions: [
          IconButton(
            onPressed: app.isLoading ? null : app.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: chargerTypes.length,
        itemBuilder: (_, idx) {
          final type = chargerTypes[idx];
          final slots = state.slots[type.id] ?? const [];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(type.description,
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const Divider(),
                  for (final s in slots) _slotRow(s),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _slotRow(ParkingSlot s) {
    final app = context.read<AppStateProvider>();
    final detail = app.state.slotDetails[s.id] ?? const SlotDetail();
    final customName = app.state.slotNames[s.id];
    final label = customName != null && customName.isNotEmpty
        ? customName
        : '${chargerTypeById(s.typeId)?.name ?? s.typeId} ${s.id.split('-').last}번';

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

    return InkWell(
      onTap: () => _editSlot(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
                  Text(
                    '${s.id}${detail.vehicleNumber.isEmpty ? "" : " · ${detail.vehicleNumber}"}${detail.ownerNickname.isEmpty ? "" : " · ${detail.ownerNickname}"}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Text(status, style: TextStyle(color: color, fontSize: 12)),
            const Icon(Icons.edit, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }
}
