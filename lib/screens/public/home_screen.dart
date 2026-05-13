import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/deep_link.dart';
import '../../core/duration_presets.dart';
import '../../models/parking_slot.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import 'map_view_screen.dart';

/// 홈 화면 — 사용 현황 요약 + B1/B2 평면도 지도(핀치 줌).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppStateProvider>();
      await app.start();
      if (!mounted) return;
      await _maybeOpenDeepLinkSlot();
    });
  }

  /// NFC 태그 / QR / 외부 링크가 ?slot=<id> 로 앱을 진입시켰을 때.
  /// 다이얼로그를 띄우지 않고 즉시 주차 등록을 완료한다 — 사용자 차량/연락처를
  /// 세션에서, 시작 시간을 현재 시각으로, 충전 시간을 충전기 종류 표준값으로 자동 채움.
  /// 충돌(이미 점유·차단·내 차가 다른 슬롯에 등록 등)은 안내 SnackBar 로 처리.
  Future<void> _maybeOpenDeepLinkSlot() async {
    final pending = DeepLink.consumePendingSlot();
    if (pending == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppStateProvider>();
    final auth = context.read<AuthProvider>();
    final session = auth.session;

    if (session == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    // 자동 등록 직전 항상 최신 서버 상태 강제 동기화 — 다른 사용자의 점유·차단 상태를
    // 정확히 감지하기 위함. 캐시가 stale 일 가능성을 차단.
    app.invalidateStateCache();
    await app.refresh();
    if (!mounted) return;

    ParkingSlot? matched;
    for (final list in app.state.slots.values) {
      for (final s in list) {
        if (s.id == pending) {
          matched = s;
          break;
        }
      }
      if (matched != null) break;
    }
    if (matched == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('슬롯을 찾을 수 없습니다: $pending')),
      );
      return;
    }

    final detail = app.state.slotDetails[matched.id] ?? const SlotDetail();

    if (detail.parkingBlocked) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${matched.id} 는 현재 주차 불가 상태입니다.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }
    final isOwnedByMe = detail.ownerEmail == session.email;
    final isOwnedByOther = detail.ownerEmail.isNotEmpty && !isOwnedByMe;
    if (isOwnedByOther) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${matched.id} 는 이미 다른 사용자가 사용 중입니다.'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    // 본인이 이미 점유 중이면 자동 출차 처리.
    if (isOwnedByMe) {
      try {
        await app.clearSlotDetail(matched.id);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('${matched.id} 자동 출차 완료'),
            backgroundColor: Colors.blueGrey.shade700,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('자동 출차 실패: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (session.vehicleNumber.trim().isEmpty ||
        session.phoneNumber.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('내 정보(차량번호·전화번호)를 먼저 등록해 주세요.'),
        ),
      );
      return;
    }

    // 다른 슬롯에 내 차가 이미 등록돼 있으면 자동 이동 — 사용자 확인 SnackBar 안내만.
    final myOtherSlot = app.findMyOwnedSlot(session.email);
    try {
      if (myOtherSlot != null && myOtherSlot != matched.id) {
        await app.clearSlotDetail(myOtherSlot);
      }

      final start = DateTime.now();
      final durationMinutes = defaultDurationMinutesFor(matched.typeId);
      final departure = start.add(Duration(minutes: durationMinutes));

      final autoDetail = SlotDetail(
        vehicleNumber: session.vehicleNumber.trim(),
        contact: session.phoneNumber.trim(),
        contactVisible: false,
        startTime: start.toIso8601String(),
        departureTime: departure.toIso8601String(),
        chargeDuration: formatDurationMinutes(durationMinutes),
        ownerEmail: session.email,
        ownerNickname:
            session.nickname.isNotEmpty ? session.nickname : session.name,
        parkingBlocked: false,
      );

      await app.upsertSlotDetail(slotId: matched.id, detail: autoDetail);

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${matched.id} 자동 주차 등록 완료 — 충전 ${formatDurationMinutes(durationMinutes)} 예약',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('자동 등록 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _checkoutMyCar(String slotId) async {
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppStateProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('출차'),
        content: const Text('내 차량을 출차 처리할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('출차'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.clearSlotDetail(slotId);
      messenger.showSnackBar(const SnackBar(content: Text('출차 처리되었습니다.')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('출차 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final auth = context.watch<AuthProvider>();
    final session = auth.session;
    final myOwnedSlotId = session != null ? app.findMyOwnedSlot(session.email) : null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            _SummaryCard(
              totalOccupied: app.state.occupiedSlots(),
              total: app.state.totalSlots(),
              lastUpdated: app.lastUpdated,
              isLoading: app.isLoading,
              errorMessage: app.errorMessage,
              onRefresh: app.refresh,
              myOwnedSlotId: myOwnedSlotId,
              onCheckout: myOwnedSlotId == null ? null : () => _checkoutMyCar(myOwnedSlotId),
            ),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                labelColor: Colors.black,
                tabs: [
                  Tab(text: 'B1'),
                  Tab(text: 'B2'),
                ],
              ),
            ),
            const Expanded(
              child: FloorMapView(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalOccupied,
    required this.total,
    required this.lastUpdated,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.myOwnedSlotId,
    required this.onCheckout,
  });

  final int totalOccupied;
  final int total;
  final DateTime? lastUpdated;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final String? myOwnedSlotId;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lastUpdated == null && isLoading)
                      const _SkeletonBar(width: 160, height: 22)
                    else
                      Text('$totalOccupied / $total 사용 중',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      lastUpdated != null
                          ? '마지막 갱신: ${_formatTime(lastUpdated!)}'
                          : '로딩 중...',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          if (myOwnedSlotId != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCheckout,
                icon: const Icon(Icons.directions_car_outlined),
                label: Text('내 차량($myOwnedSlotId) 출차하기'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final l = t.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(l.hour)}:${pad(l.minute)}:${pad(l.second)}';
  }
}

/// 콜드 스타트 + 캐시 미적중 시에만 노출되는 회색 막대 placeholder.
class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
