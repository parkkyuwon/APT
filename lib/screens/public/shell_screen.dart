import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../admin/admin_dashboard.dart';
import 'chat_screen.dart';
import 'guide_screen.dart';
import 'highlight_screen.dart';
import 'home_screen.dart';
import 'map_view_screen.dart';
import 'mypage_screen.dart';
import 'parking_list_screen.dart';

/// 승인된 사용자가 진입하는 메인 쉘. 하단 5탭 네비게이션.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

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
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: '대화방'),
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
      appBar: AppBar(title: const Text('더보기'), automaticallyImplyLeading: false),
      body: ListView(
        children: [
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
