import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/user.dart';
import '../../services/services.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<ApiServices>().users.list(
            status: _pendingOnly ? 'pending' : null,
            view: 'approval',
            limit: _pendingOnly ? 100 : 200,
          );
      if (!mounted) return;
      setState(() => _users = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateAccess(String email, String status, String role) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ApiServices>().users.updateAccess(
            email: email,
            status: status,
            role: role,
          );
      await _load();
      messenger.showSnackBar(SnackBar(content: Text('$email → $status')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _verifyVehicle(String email, bool approved) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ApiServices>().users.verifyVehicle(
            email: email,
            approved: approved,
          );
      await _load();
      messenger.showSnackBar(
        SnackBar(content: Text('$email 차량 ${approved ? '승인' : '취소'}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원 승인'),
        actions: [
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
    String statusText;
    Color statusColor;
    switch (u.status) {
      case AuthStatus.approved:
        statusText = u.vehicleVerified ? '승인' : '차량 인증 대기';
        statusColor = u.vehicleVerified ? Colors.green : Colors.orange;
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
                      if (u.nickname.isNotEmpty)
                        Text(u.nickname, style: const TextStyle(fontSize: 12)),
                      if (u.vehicleNumber.isNotEmpty)
                        Text('차량: ${u.vehicleNumber}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () => _updateAccess(u.email, 'approved', 'user'),
                  child: const Text('사용자 승인'),
                ),
                OutlinedButton(
                  onPressed: () => _updateAccess(u.email, 'approved', 'admin'),
                  child: const Text('관리자 승인'),
                ),
                OutlinedButton(
                  onPressed: () => _updateAccess(u.email, 'rejected', 'user'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('거절'),
                ),
                OutlinedButton(
                  onPressed: () => _updateAccess(u.email, 'blocked', 'user'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('차단'),
                ),
                if (u.vehicleNumber.isNotEmpty)
                  OutlinedButton(
                    onPressed: () => _verifyVehicle(u.email, !u.vehicleVerified),
                    child: Text(u.vehicleVerified ? '차량승인 취소' : '차량승인'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
