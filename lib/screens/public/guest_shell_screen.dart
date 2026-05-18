import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import 'guide_screen.dart';
import 'map_view_screen.dart';
import 'parking_list_screen.dart';

/// 비회원 게스트 진입 Shell. 읽기 전용 3탭.
class GuestShellScreen extends StatefulWidget {
  const GuestShellScreen({super.key});

  @override
  State<GuestShellScreen> createState() => _GuestShellScreenState();
}

class _GuestShellScreenState extends State<GuestShellScreen> {
  int _index = 0;

  static const _screens = <Widget>[
    ParkingListScreen(),
    MapViewScreen(),
    GuideScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppStateProvider>().startGuest();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Colors.blue.shade50,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '비회원 모드 — 현재 주차 현황만 볼 수 있습니다.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.read<AuthProvider>().exitGuestMode(),
                      child: const Text('로그인하기'),
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
          NavigationDestination(icon: Icon(Icons.list_alt), label: '목록'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: '지도'),
          NavigationDestination(
              icon: Icon(Icons.help_outline), label: '이용안내'),
        ],
      ),
    );
  }
}
