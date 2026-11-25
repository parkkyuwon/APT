import 'package:flutter/material.dart';

/// [guide.html] — 처음 이용 안내.
///
/// 웹의 이미지 캡처(guide-login.png 등)는 Phase 3 에서 asset 복사가 완료되면 표시.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('처음 이용 안내')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Start',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '로그인 → 승인 → 주차 등록',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '구글 로그인 후 닉네임을 입력하고 차량번호 한 개와 번호판 사진을 비교하고 '
                    '관리자 승인을 받으면 주차 등록을 시작할 수 있습니다.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '처음 사용할 때',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _step('1. 구글 로그인', '로그인 화면에서 구글 계정으로 가입 또는 로그인을 진행합니다.'),
          _step('2. 닉네임과 차량번호 확인',
              '닉네임과 차량번호 한 개를 입력하고 번호판 사진 OCR 비교 후 가입을 요청합니다. 차량번호 변경 시 기존 차량을 대체하고 관리자 재승인을 받아야 합니다.'),
          _step(
              '3. 관리자 승인', '최초 사용자는 관리자 승인이 끝난 뒤 메인 화면과 주차 등록 기능을 사용할 수 있습니다.'),
          _step(
            '4. 주차 등록과 출차',
            '홈 또는 목록 탭에서 원하는 주차칸을 선택한 뒤 차량번호와 예상 출차시간을 입력해 등록하고, '
                '이후에는 홈 상단의 "내 차량 출차하기" 버튼이나 QR로 빠르게 정리할 수 있습니다.',
          ),
          const SizedBox(height: 20),
          const Text(
            '꼭 알아둘 규칙',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _bullet('필수 입력 항목은 차량번호와 충전 소요 시간입니다.'),
          _bullet('한 계정은 한 번에 1개의 주차만 등록할 수 있습니다.'),
          _bullet('다른 사용자가 등록한 주차 정보는 수정할 수 없고, 본인 차량만 등록 또는 출차할 수 있습니다.'),
          _bullet('3kW 완속 구역은 상황에 따라 주차 불가로 표시될 수 있습니다.'),
          _bullet(
              '현장 QR을 스캔하면 해당 자리로 바로 이동하며, 빈 칸이면 주차, 내 차량이면 출차 흐름으로 연결됩니다.'),
        ],
      ),
    );
  }

  Widget _step(String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
