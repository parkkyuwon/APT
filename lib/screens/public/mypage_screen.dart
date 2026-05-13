import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/parking_history.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';
import '../onboarding/profile_setup_screen.dart';

/// [mypage.html] — 내 정보 + 주차 이용 내역(날짜 필터).
class MypageScreen extends StatefulWidget {
  const MypageScreen({super.key});

  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends State<MypageScreen> {
  AppUser? _user;
  List<ParkingHistoryRecord> _history = [];
  bool _loading = false;
  String? _error;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<ApiServices>().myHistory.fetchMine(
            from: _from?.toIso8601String().substring(0, 10),
            to: _to?.toIso8601String().substring(0, 10),
          );
      setState(() {
        _user = result.user;
        _history = result.records;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _to = d);
  }

  Future<void> _withdraw() async {
    final messenger = ScaffoldMessenger.of(context);
    final services = context.read<ApiServices>();
    final auth = context.read<AuthProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정 탈퇴'),
        content: const Text(
          '정말로 탈퇴하시겠습니까?\n\n'
          '탈퇴 후 7일간 재가입이 불가하며 '
          '주차 이력, 활동 기록 등 모든 데이터가 삭제됩니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('탈퇴', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await services.profile.withdraw();
      await auth.bootstrap(); // 세션 무효화 → 재부트스트랩
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('탈퇴 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final dateOnly = DateFormat('yyyy-MM-dd');
    final session = context.watch<AuthProvider>().session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 이용 내역'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.person)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_user?.nickname.isNotEmpty == true
                                        ? _user!.nickname
                                        : (_user?.name ?? session?.name ?? '사용자'))
                                    .toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _user?.email ?? session?.email ?? '',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _kv('차량번호', _user?.vehicleNumber ?? session?.vehicleNumber ?? '—'),
                    _kv('전화번호', _user?.phoneNumber ?? session?.phoneNumber ?? '—'),
                    _kv(
                      '가입일',
                      _user?.createdAt != null ? dateOnly.format(_user!.createdAt!) : '—',
                    ),
                    _kv(
                      '승인일',
                      _user?.approvedAt != null ? dateOnly.format(_user!.approvedAt!) : '—',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('정보 수정'),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const ProfileSetupScreen(isEdit: true),
                              ));
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('탈퇴'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: _withdraw,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '입차·출차 내역',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFrom,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_from == null ? '시작 날짜' : dateOnly.format(_from!)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTo,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_to == null ? '종료 날짜' : dateOnly.format(_to!)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _load,
                            child: const Text('조회'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _from = null;
                                _to = null;
                              });
                              _load();
                            },
                            child: const Text('초기화'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    if (_history.isEmpty && !_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('이용 내역이 없습니다.')),
                      ),
                    for (final r in _history) _historyRow(r, df),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
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

  Widget _historyRow(ParkingHistoryRecord r, DateFormat df) {
    final isActive = r.endTime == null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(r.slotId, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isActive ? '주차 중' : '출차 완료',
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (r.vehicleNumber.isNotEmpty)
            Text('차량: ${r.vehicleNumber}', style: const TextStyle(fontSize: 12)),
          if (r.startTime != null)
            Text('입차: ${df.format(r.startTime!.toLocal())}',
                style: const TextStyle(fontSize: 12)),
          if (r.endTime != null)
            Text('출차: ${df.format(r.endTime!.toLocal())}',
                style: const TextStyle(fontSize: 12)),
          if (r.chargeDuration.isNotEmpty)
            Text('충전: ${r.chargeDuration}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
