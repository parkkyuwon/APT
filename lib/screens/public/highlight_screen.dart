import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../services/public_api.dart';
import '../../services/services.dart';

/// [highlight.html] — 사용 중인 충전기를 용량별 그룹으로 표시, 30초 자동 갱신.
class HighlightScreen extends StatefulWidget {
  const HighlightScreen({super.key});

  @override
  State<HighlightScreen> createState() => _HighlightScreenState();
}

class _HighlightScreenState extends State<HighlightScreen> {
  HighlightResult? _result;
  bool _loading = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await context.read<ApiServices>().publicHighlight.fetch();
      if (mounted) {
        setState(() {
          _result = r;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('현재 사용중인 충전기 현황'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_result == null && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _result == null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      );
    }
    final r = _result;
    if (r == null || r.groups.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.ev_station, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('현재 사용 중인 충전기가 없습니다.'),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.ev_station, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '사용중 ${r.totalActive}대',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue),
                ),
                const Spacer(),
                const Text('30초 자동 갱신', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final g in r.groups) _group(g),
      ],
    );
  }

  Widget _group(HighlightGroup g) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(g.chargerType,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${g.items.length}대 사용중',
                      style: const TextStyle(fontSize: 12, color: Colors.blue)),
                ),
              ],
            ),
            const Divider(),
            for (final item in g.items) _item(item),
          ],
        ),
      ),
    );
  }

  Widget _item(HighlightItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.slotName, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('차량번호: ${item.vehicleNumberMasked}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text('주차 시작: ${_fmt(item.startTime)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text('예상 출차: ${_fmt(item.departureTime)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          if (item.chargeDuration.isNotEmpty)
            Text('충전 시간: ${item.chargeDuration}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    if (iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MM/dd HH:mm').format(dt.toLocal());
  }
}
