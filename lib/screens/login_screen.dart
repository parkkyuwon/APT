import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// 로그인 화면 — Google 로그인 단일 경로.
///
/// Phase 8.2: 관리자 ID/PW 숨김 토글 제거. 관리자 권한은 백엔드의
/// `ADMIN_EMAILS` 환경변수에 등록된 이메일에만 부여된다.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final err = auth.errorMessage;
    return Scaffold(
      appBar: AppBar(title: const Text('APT EV 충전')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.ev_station, size: 72, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                '아파트 전기차 충전 주차 현황',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '처음 접속한 계정은 관리자 승인 후 이용 가능합니다.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: auth.isBusy ? null : auth.loginWithGoogle,
                icon: const Icon(Icons.account_circle),
                label: Text(auth.isBusy ? '로그인 중...' : 'Google로 로그인'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: auth.isBusy
                    ? null
                    : () => context.read<AuthProvider>().enterGuestMode(),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('비회원으로 둘러보기'),
              ),
              if (err != null && err.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(err, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
