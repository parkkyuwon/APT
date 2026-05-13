import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/user.dart';
import '../../services/services.dart';
import 'console_parking_history.dart';

/// [console_member_usage_k9r2m4x.html] — 회원 사용 정보 목록.
class ConsoleMemberUsage extends StatefulWidget {
  const ConsoleMemberUsage({super.key});

  @override
  State<ConsoleMemberUsage> createState() => _ConsoleMemberUsageState();
}

class _ConsoleMemberUsageState extends State<ConsoleMemberUsage> {
  List<AppUser> _users = [];
  bool _loading = false;
  String? _error;
  String _search = '';

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
            view: 'full',
            limit: 300,
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

  List<AppUser> get _filtered {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) {
      return u.email.toLowerCase().contains(q) ||
          u.nickname.toLowerCase().contains(q) ||
          u.vehicleNumber.toLowerCase().contains(q) ||
          u.phoneNumber.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text('회원 사용 정보 (${filtered.length})'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '이메일/닉네임/차량/전화 검색',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final u = filtered[i];
                  return Card(
                    child: ListTile(
                      title: Text(u.email, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('닉네임: ${u.nickname.isEmpty ? "-" : u.nickname}'),
                          Text('차량: ${u.vehicleNumber.isEmpty ? "-" : u.vehicleNumber}'),
                          Text('전화: ${u.phoneNumber.isEmpty ? "-" : u.phoneNumber}'),
                          Text('상태: ${u.status.name} · 권한: ${u.role}',
                              style: const TextStyle(fontSize: 11)),
                          if (u.createdAt != null)
                            Text('가입: ${df.format(u.createdAt!)}',
                                style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          if (u.approvedAt != null)
                            Text('승인: ${df.format(u.approvedAt!)}',
                                style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.history),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ConsoleParkingHistory(initialEmail: u.email),
                          ));
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
