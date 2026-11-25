import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/deep_link.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/push_notifications.dart';
import '../../services/indoor_access_controller.dart';
import 'indoor_position_screen.dart';
import 'home_area_settings_screen.dart';
import '../admin/admin_dashboard.dart';
import 'chat_screen.dart';
import 'board_screen.dart';
import 'charger_reports_screen.dart';
import 'guide_screen.dart';
import 'highlight_screen.dart';
import 'home_screen.dart';
import 'map_view_screen.dart';
import 'mypage_screen.dart';
import 'parking_list_screen.dart';
import 'departure_requests_screen.dart';

/// 승인된 사용자가 진입하는 메인 쉘. 하단 5탭 네비게이션.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;
  PushNotifications? _push;
  IndoorAccessController? _indoor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final push = context.read<PushNotifications>();
    final indoor = context.read<IndoorAccessController>();
    if (_indoor != indoor) {
      _indoor?.removeListener(_onIndoor);
      _indoor = indoor;
      indoor.addListener(_onIndoor);
      _onIndoor();
    }
    if (_push == push) return;
    _push?.removeListener(_onPush);
    _push = push;
    push.addListener(_onPush);
    _onPush();
  }

  void _onIndoor() {
    if (!mounted || _indoor?.pendingVisit == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final shouldOpen = await _indoor!.takeEntry();
      if (mounted && shouldOpen) {
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const IndoorPositionScreen()));
      }
    });
  }

  void _onPush() {
    if (!mounted || _push?.pendingRequestId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = _push?.takePendingRequest();
      if (id != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DepartureRequestsScreen(initialRequestId: id)));
      }
    });
  }

  void _onDeepLink() {
    if (mounted && _index != 0) setState(() => _index = 0);
  }

  @override
  void initState() {
    super.initState();
    DeepLink.addListener(_onDeepLink);
  }

  @override
  void dispose() {
    DeepLink.removeListener(_onDeepLink);
    _push?.removeListener(_onPush);
    _indoor?.removeListener(_onIndoor);
    super.dispose();
  }

  static const _screens = <Widget>[
    HomeScreen(),
    ParkingListScreen(),
    ChatScreen(),
    MypageScreen(),
    _MoreMenu(),
  ];

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    return Scaffold(
      body: Column(
        children: [
          if (isOffline)
            Material(
              color: Colors.amber.shade100,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, size: 16, color: Colors.brown),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '오프라인 — 마지막으로 본 정보를 표시합니다.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.brown.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: _screens[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: '홈'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: '목록'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: '대화방'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '내정보'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: '더보기'),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar:
          AppBar(title: const Text('더보기'), automaticallyImplyLeading: false),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('지하 내 위치'),
            subtitle: const Text('관리자가 배포한 비콘 정보로 위치 찾기'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const IndoorPositionScreen())),
          ),
          if (auth.session != null)
            ListTile(
              leading: const Icon(Icons.radar),
              title: const Text('집 주변 지하 위치 안내'),
              subtitle: const Text('주변 반경 설정 · 위치 신호 저하 시 알림'),
              onTap: () {
                final scope = auth.session!.email;
                final access = context.read<IndoorAccessController>();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HomeAreaSettingsScreen(
                        accountScope: scope,
                        serviceEnabled: () =>
                            access.enabled &&
                            auth.session?.email == scope &&
                            (auth.stage == AuthStage.approved ||
                                auth.stage == AuthStage.admin))));
              },
            ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('지도 보기'),
            subtitle: const Text('B1/B2 평면도 + 슬롯 위치 마커'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MapViewScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_border),
            title: const Text('대표 현황'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HighlightScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('이용 안내'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GuideScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: const Text('아파트 게시판'),
            subtitle: const Text('단지의 이슈와 의견을 나눕니다.'),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BoardScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.report_problem_outlined),
            title: const Text('충전기 고장 신고'),
            subtitle: const Text('사진과 함께 신고하고 처리 상태를 확인합니다.'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ChargerReportsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('받은 출차 요청'),
            subtitle: const Text('요청한 차량과 주차 위치 확인'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const DepartureRequestsScreen())),
          ),
          Consumer<PushNotifications>(
              builder: (_, push, __) => ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('휴대폰 출차 요청 알림'),
                    subtitle: Text(push.status),
                    trailing: push.configured && !push.enabled
                        ? TextButton(
                            onPressed: push.enable, child: const Text('알림 켜기'))
                        : null,
                  )),
          if (auth.isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('관리자 콘솔'),
              subtitle: const Text('허브 + 회원 승인, 운영 설정, QR, 지도 편집 등'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminDashboard()),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: auth.logout,
          ),
          const SizedBox(height: 24),
          if (auth.session != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.session!.email,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  Text(
                    '권한: ${auth.isAdmin ? '관리자' : '일반 사용자'}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
