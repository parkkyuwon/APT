import 'package:flutter/material.dart';

import '../core/privacy.dart';
import '../models/parking_slot.dart';
import '../models/session.dart';
import '../theme.dart';

enum SlotStatus { available, occupied, maintenance, owned }

/// 주차 슬롯 하나를 사각형 타일로 표시.
class SlotTile extends StatelessWidget {
  const SlotTile({
    required this.slotId,
    required this.typeId,
    required this.label,
    required this.detail,
    required this.status,
    required this.onTap,
    this.session,
    super.key,
  });

  final String slotId;
  final String typeId;
  final String label;
  final SlotDetail detail;
  final SlotStatus status;
  final VoidCallback onTap;
  final SessionInfo? session;

  Color get _color {
    switch (status) {
      case SlotStatus.available:
        return AppColors.available;
      case SlotStatus.occupied:
        return AppColors.occupied;
      case SlotStatus.maintenance:
        return AppColors.maintenance;
      case SlotStatus.owned:
        return AppColors.owned;
    }
  }

  String get _statusLabel {
    switch (status) {
      case SlotStatus.available:
        return '사용 가능';
      case SlotStatus.occupied:
        return '사용 중';
      case SlotStatus.maintenance:
        return '주차 불가';
      case SlotStatus.owned:
        return '내 차량';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          border: Border.all(
            color: ChargerColors.forTypeId(typeId),
            width: 3,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _statusLabel,
              style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w600),
            ),
            if (status == SlotStatus.occupied && detail.vehicleNumber.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                vehicleFor(session, detail.vehicleNumber),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
