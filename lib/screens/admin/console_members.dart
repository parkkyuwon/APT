import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/user.dart';
import '../../services/services.dart';
import 'member_management_screen.dart';
import 'console_vehicle_verify.dart';

/// [console_members_k9r2m4x.html] — 회원 승인/거절/차단.
class ConsoleMembers extends StatefulWidget {
  const ConsoleMembers({super.key});

  @override
  State<ConsoleMembers> createState() => _ConsoleMembersState();
}

class _ConsoleMembersState extends State<ConsoleMembers> {
  bool _pendingOnly = true;
  List<AppUser> _users = [];
  bool _loading = false;
  String? _error;
  int _loadGeneration = 0;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<ApiServices>().users.list(
            status: _pendingOnly ? 'pending' : null,
            view: 'approval',
            limit: 100,
          );
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _users = list);
    } on ApiException catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = e.message);
      }
    } on NetworkException catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = '조회 실패: $e');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _confirm(AppUser u, String action, String consequence) async {
    return await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                  title: Text('$action 확인'),
                  content:
                      Text('${u.email}\n차량: ${u.vehicleNumber}\n$consequence'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('취소')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(action)),
                  ],
                )) ??
        false;
  }

  Future<void> _updateAccess(AppUser u, String status, String role) async {
    if (_processing.contains(u.email)) return;
    setState(() => _processing.add(u.email));
    try {
      final sensitive = status != 'approved' || role == 'admin' || u.isAdmin;
      if (sensitive &&
          !await _confirm(
              u,
              status == 'blocked'
                  ? '차단'
                  : status == 'rejected'
                      ? '거절'
                      : role == 'admin'
                          ? '관리자 승인'
                          : '관리자 권한 해제',
              status == 'approved' ? '회원 권한이 변경됩니다.' : '회원의 앱 이용이 제한됩니다.')) {
        return;
      }
      if (!mounted) return;
      await context.read<ApiServices>().users.updateAccess(
            email: u.email,
            status: status,
            role: role,
            expectedMemberCreatedAt: u.createdAt,
            expectedVehicleSubmissionVersion: u.vehicleSubmissionVersion,
          );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${u.email} → $status')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('실패: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processing.remove(u.email));
    }
  }

  Future<void> _reviewVehicle(AppUser u) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => ConsoleVehicleVerify(email: u.email)));
    if (mounted) await _load();
  }

  Future<void> _cancelVehicleVerification(AppUser u) async {
    if (_processing.contains(u.email)) return;
    setState(() => _processing.add(u.email));
    try {
      if (!await _confirm(
          u, '차량승인 취소', '차량 인증 또는 면제 승인을 취소하며 회원 이용은 재승인 전까지 제한됩니다.')) {
        return;
      }
      if (!mounted) return;
      await context.read<ApiServices>().users.verifyVehicle(
            email: u.email,
            approved: false,
            expectedMemberCreatedAt: u.createdAt,
            expectedVehicleSubmissionVersion: u.vehicleSubmissionVersion,
          );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${u.email} 차량 승인 취소')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('실패: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _processing.remove(u.email));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원 승인'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MemberManagementScreen(
                      initialIncompleteOnly: true))),
              child: const Text('회원 정리')),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('미승인만'),
                  selected: _pendingOnly,
                  onSelected: (v) {
                    setState(() => _pendingOnly = v);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('전체'),
                  selected: !_pendingOnly,
                  onSelected: (v) {
                    setState(() => _pendingOnly = !v);
                    _load();
                  },
                ),
                const Spacer(),
                Text('${_users.length}명',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade50,
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _users.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('해당 회원이 없습니다.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _memberCard(_users[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(AppUser u) {
    final busy = _processing.contains(u.email) || _loading;
    final vehicleReady = u.vehicleVerified ||
        u.vehicleVerificationExempt ||
        !u.vehicleVerificationRequired;
    final canApprove = u.profileComplete && u.consentAt != null && vehicleReady;
    final reason = u.consentAt == null
        ? '약관 동의가 필요합니다.'
        : !u.profileComplete
            ? '회원 프로필 입력이 필요합니다.'
            : !vehicleReady
                ? '차량 사진 검토 및 승인이 필요합니다.'
                : null;
    String statusText;
    Color statusColor;
    switch (u.status) {
      case AuthStatus.approved:
        statusText = u.vehicleVerificationExempt
            ? '승인 · 사진 인증 면제'
            : u.vehicleVerified
                ? '승인'
                : '차량 인증 대기';
        statusColor = (u.vehicleVerified || u.vehicleVerificationExempt)
            ? Colors.green
            : Colors.orange;
        break;
      case AuthStatus.rejected:
        statusText = '거절';
        statusColor = Colors.red;
        break;
      case AuthStatus.blocked:
        statusText = '차단';
        statusColor = Colors.red;
        break;
      case AuthStatus.withdrawn:
        statusText = '탈퇴';
        statusColor = Colors.grey;
        break;
      default:
        statusText = '승인 대기';
        statusColor = Colors.blue;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.email,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (u.name.isNotEmpty)
                        Text(u.name, style: const TextStyle(fontSize: 12)),
                      if (u.nickname.isNotEmpty)
                        Text('닉네임: ${u.nickname}',
                            style: const TextStyle(fontSize: 12)),
                      if (u.vehicleNumber.isNotEmpty)
                        Text('차량: ${u.vehicleNumber}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (u.vehicleVerificationExempt)
              const Text('사진·OCR 면제 승인 (사진 인증과 별도)'),
            if (!u.vehicleVerificationRequired) const Text('현재 사진·OCR 인증 선택'),
            if (reason != null)
              Text(reason, style: const TextStyle(color: Colors.orange)),
            if (_processing.contains(u.email)) const Text('처리 중…'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: !busy && canApprove
                      ? () => _updateAccess(u, 'approved', 'user')
                      : null,
                  child: const Text('사용자 승인'),
                ),
                OutlinedButton(
                  onPressed: !busy && canApprove
                      ? () => _updateAccess(u, 'approved', 'admin')
                      : null,
                  child: const Text('관리자 승인'),
                ),
                OutlinedButton(
                  onPressed:
                      busy ? null : () => _updateAccess(u, 'rejected', 'user'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('거절'),
                ),
                OutlinedButton(
                  onPressed:
                      busy ? null : () => _updateAccess(u, 'blocked', 'user'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('차단'),
                ),
                if (u.vehicleNumber.isNotEmpty)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : (u.vehicleVerified || u.vehicleVerificationExempt)
                            ? () => _cancelVehicleVerification(u)
                            : () => _reviewVehicle(u),
                    child: Text(
                        (u.vehicleVerified || u.vehicleVerificationExempt)
                            ? '차량승인 취소'
                            : '사진 검토'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
