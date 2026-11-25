import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// 승인 대기 화면. 관리자가 웹에서 승인하면 새로고침 시 자동으로 approved 로 전환.
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 승인 대기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: auth.isBusy ? null : auth.bootstrap,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.pending_actions, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                '관리자 승인 대기 중입니다.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                '입력하신 정보를 관리자가 확인한 후 서비스를 이용할 수 있습니다.\n'
                '승인 후 아래 상태 다시 확인 버튼을 누르면 서비스를 이용할 수 있습니다.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (auth.session != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('이메일', auth.session!.email),
                        if (auth.session!.name.isNotEmpty)
                          _row('이름', auth.session!.name),
                        if (auth.session!.nickname.isNotEmpty)
                          _row('닉네임', auth.session!.nickname),
                        if (auth.session!.vehicleNumber.isNotEmpty)
                          _row('차량번호', auth.session!.vehicleNumber),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: auth.isBusy ? null : auth.bootstrap,
                icon: const Icon(Icons.refresh),
                label: const Text('상태 다시 확인'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: auth.logout,
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
