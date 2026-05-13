import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/services.dart';

/// [consent.html](D:/vsCodeProg/APT-Prj/consent.html) 동등 화면.
///
/// 승인된 사용자 중 `consent_at` 이 비어 있는 경우 노출되며, 동의 체크
/// 후 POST /api/profile { action: "consent", version: "1.0" } 호출.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  static const _items = <_ConsentItem>[
    _ConsentItem(
      field: '이메일, 이름, 프로필 사진',
      purpose: 'Google 계정 인증 및 본인 확인',
      retention: '탈퇴 시 삭제',
    ),
    _ConsentItem(
      field: '닉네임',
      purpose: '서비스 내 표시명',
      retention: '탈퇴 후 7일 삭제',
      emphasize: true,
    ),
    _ConsentItem(
      field: '차량번호',
      purpose: '주차 슬롯 등록 및 차량 식별',
      retention: '탈퇴 후 7일 삭제',
      emphasize: true,
    ),
    _ConsentItem(
      field: '전화번호',
      purpose: '본인 확인 및 긴급 연락',
      retention: '탈퇴 후 7일 삭제',
      emphasize: true,
    ),
    _ConsentItem(
      field: '차량 사진',
      purpose: '가입 시 본인 확인 (관리자 검토용)',
      retention: '관리자 검토 후 즉시 삭제',
      emphasize: true,
    ),
    _ConsentItem(
      field: '주차 이용 이력',
      purpose: '서비스 이용 기록 관리',
      retention: '탈퇴 후 7일 삭제',
    ),
    _ConsentItem(
      field: '접속 기록 (IP, 브라우저 정보)',
      purpose: '서비스 보안 및 운영',
      retention: '90일 후 자동 삭제',
    ),
  ];

  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final services = context.read<ApiServices>();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await services.profile.recordConsent();
      auth.markConsentRecorded();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _decline() async {
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 수집 및 이용 동의')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '서비스 이용을 위해 아래 개인정보 수집 및 이용에 동의해 주세요. '
                '동의하지 않으면 서비스를 이용할 수 없습니다.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _header(),
                      const Divider(height: 1),
                      ..._items.map((e) => _row(e)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _agreed,
                onChanged: _submitting ? null : (v) => setState(() => _agreed = v ?? false),
                title: const Text('개인정보 수집 및 이용에 동의합니다. (필수)'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _decline,
                      child: const Text('동의하지 않음'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_agreed && !_submitting) ? _submit : null,
                      child: Text(_submitting ? '저장 중...' : '동의하고 계속하기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    const style = TextStyle(fontWeight: FontWeight.w600, fontSize: 13);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('수집 항목', style: style)),
          Expanded(flex: 4, child: Text('수집 목적', style: style)),
          Expanded(flex: 3, child: Text('보존 기간', style: style)),
        ],
      ),
    );
  }

  Widget _row(_ConsentItem item) {
    final style = TextStyle(fontSize: 12.5, fontWeight: item.emphasize ? FontWeight.w600 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(item.field, style: style)),
          Expanded(flex: 4, child: Text(item.purpose, style: style.copyWith(fontWeight: FontWeight.w400))),
          Expanded(flex: 3, child: Text(item.retention, style: style.copyWith(fontWeight: FontWeight.w400))),
        ],
      ),
    );
  }
}

class _ConsentItem {
  const _ConsentItem({
    required this.field,
    required this.purpose,
    required this.retention,
    this.emphasize = false,
  });

  final String field;
  final String purpose;
  final String retention;
  final bool emphasize;
}
