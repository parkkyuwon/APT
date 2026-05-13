import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/parking_history.dart';
import '../../services/services.dart';

/// [console_parking_history_k9r2m4x.html] — 특정 회원의 입/출차 이력 페이지네이션.
class ConsoleParkingHistory extends StatefulWidget {
  const ConsoleParkingHistory({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ConsoleParkingHistory> createState() => _ConsoleParkingHistoryState();
}

class _ConsoleParkingHistoryState extends State<ConsoleParkingHistory> {
  final _emailCtrl = TextEditingController();
  final _records = <ParkingHistoryRecord>[];
  DateTime? _from;
  DateTime? _to;
  bool _loading = false;
  bool _hasMore = false;
  int _offset = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail.isNotEmpty) {
      _emailCtrl.text = widget.initialEmail;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _search({bool reset = true}) async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final fetchOffset = reset ? 0 : _offset;
    try {
      final page = await context.read<ApiServices>().myHistory.fetchForUser(
            email: email,
            from: _from?.toIso8601String().substring(0, 10),
            to: _to?.toIso8601String().substring(0, 10),
            offset: fetchOffset,
            limit: 50,
          );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _records.clear();
          _offset = 0;
        }
        _records.addAll(page.records);
        _hasMore = page.hasMore;
        _offset += page.records.length;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
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

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MM/dd HH:mm');
    final dateOnly = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: const Text('입/출차 이력')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.emailAddress,
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
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _search,
                        icon: const Icon(Icons.search),
                        label: const Text('조회'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _from = null;
                            _to = null;
                            _records.clear();
                            _offset = 0;
                          });
                        },
                        child: const Text('초기화'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade50,
              width: double.infinity,
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _records.isEmpty && !_loading
                ? const Center(child: Text('조회 결과가 없습니다.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _records.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _records.length) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: _loading ? null : () => _search(reset: false),
                              child: const Text('더 불러오기'),
                            ),
                          ),
                        );
                      }
                      final r = _records[i];
                      final isActive = r.endTime == null;
                      return Card(
                        child: ListTile(
                          title: Text(r.slotId,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (r.vehicleNumber.isNotEmpty) Text('차량: ${r.vehicleNumber}'),
                              if (r.startTime != null)
                                Text('입차: ${df.format(r.startTime!.toLocal())}'),
                              if (r.endTime != null)
                                Text('출차: ${df.format(r.endTime!.toLocal())}'),
                              if (r.chargeDuration.isNotEmpty)
                                Text('충전: ${r.chargeDuration}'),
                            ],
                          ),
                          trailing: Text(
                            isActive ? '주차 중' : '완료',
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
