import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'console_beacon_list.dart';
import 'console_beacon_scan.dart';
import 'console_logs.dart';
import 'console_member_usage.dart';
import 'console_members.dart';
import 'console_operations.dart';
import 'console_parking.dart';
import 'console_parking_history.dart';
import 'console_qr.dart';
import 'console_vehicle_verify.dart';
import 'map_editor_screen.dart';

/// [console_k9r2m4x.html] — 관리자 허브 랜딩. 7개 서브 콘솔 + 지도 편집 카드.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 허브'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: auth.logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (auth.session != null)
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${auth.session!.nickname.isEmpty ? auth.session!.name : auth.session!.nickname} (${auth.session!.email}) 관리자로 로그인 중',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 8),
          _card(
            context,
            icon: Icons.verified_user,
            title: '회원 승인',
            description: '가입 요청 사용자의 승인, 거절, 차단을 처리합니다.',
            builder: (_) => const ConsoleMembers(),
          ),
          _card(
            context,
            icon: Icons.photo_camera,
            title: '차량 사진 인증',
            description: '제출된 차량 번호판 사진을 검토하고 승인 또는 거절합니다.',
            builder: (_) => const ConsoleVehicleVerify(),
          ),
          _card(
            context,
            icon: Icons.settings,
            title: '운영 설정',
            description: '준비중 모드, 공지사항, 충전기 수량을 관리합니다.',
            builder: (_) => const ConsoleOperations(),
          ),
          _card(
            context,
            icon: Icons.local_parking,
            title: '주차 정보',
            description: '전체 주차 입력 정보와 슬롯별 상태를 직접 수정합니다.',
            builder: (_) => const ConsoleParking(),
          ),
          _card(
            context,
            icon: Icons.qr_code,
            title: 'QR 관리',
            description: '주차면별 QR을 자동 생성하고 개별 저장합니다.',
            builder: (_) => const ConsoleQr(),
          ),
          _card(
            context,
            icon: Icons.history,
            title: '입/출차 이력',
            description: '회원별 입차·출차 기록을 날짜 범위로 조회합니다.',
            builder: (_) => const ConsoleParkingHistory(),
          ),
          _card(
            context,
            icon: Icons.analytics_outlined,
            title: '활동 이력',
            description: '전체 사용자와 관리자의 최근 활동 로그를 확인합니다.',
            builder: (_) => const ConsoleLogs(),
          ),
          _card(
            context,
            icon: Icons.people_outline,
            title: '회원 사용 정보',
            description: '전체 회원의 상세 정보를 조회합니다.',
            builder: (_) => const ConsoleMemberUsage(),
          ),
          _card(
            context,
            icon: Icons.map,
            title: '지도 편집',
            description: '슬롯 좌표를 지도 이미지 위에 배치합니다.',
            builder: (_) => const MapEditorScreen(),
          ),
          _card(
            context,
            icon: Icons.bluetooth_searching,
            title: '비콘 스캔',
            description: '주변 BLE 기기·iBeacon·Eddystone 신호를 실시간 검색합니다.',
            builder: (_) => const ConsoleBeaconScan(),
          ),
          _card(
            context,
            icon: Icons.place,
            title: '등록된 비콘',
            description: '지도 위치가 매핑된 비콘 목록과 평면도 핀 보기.',
            builder: (_) => const ConsoleBeaconList(),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required WidgetBuilder builder,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
      ),
    );
  }
}
