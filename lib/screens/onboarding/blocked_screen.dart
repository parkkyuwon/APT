import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../providers/auth_provider.dart';

/// rejected / blocked / withdrawn / dormant 등 접근 불가 상태 안내 화면.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final status = auth.session?.status ?? AuthStatus.unknown;

    final String title;
    final String body;
    switch (status) {
      case AuthStatus.rejected:
        title = '가입이 거절되었습니다';
        body = '관리자가 가입 요청을 거절했습니다.\n'
            '문의사항이 있는 경우 관리자에게 연락해 주세요.';
        break;
      case AuthStatus.blocked:
        title = '계정이 차단되었습니다';
        body = '현재 계정은 서비스 이용이 제한되어 있습니다.\n'
            '차단 해제를 원하시는 경우 관리자에게 문의해 주세요.';
        break;
      case AuthStatus.withdrawn:
        title = '탈퇴된 계정입니다';
        body = '탈퇴 처리된 계정입니다.\n'
            '탈퇴 후 7일이 지나면 재가입이 가능합니다.';
        break;
      case AuthStatus.dormant:
        title = '휴면 상태입니다';
        body = '장기간 미사용으로 휴면 상태로 전환되었습니다.\n'
            '관리자에게 휴면 해제를 요청해 주세요.';
        break;
      default:
        title = '접근할 수 없는 계정입니다';
        body = auth.errorMessage ?? '알 수 없는 이유로 접근이 제한되었습니다.';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
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
}
