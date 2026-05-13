import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/user.dart';
import '../../services/services.dart';

/// [console_vehicle_verify_k9r2m4x.html] — 제출된 차량 사진 검토.
class ConsoleVehicleVerify extends StatefulWidget {
  const ConsoleVehicleVerify({super.key});

  @override
  State<ConsoleVehicleVerify> createState() => _ConsoleVehicleVerifyState();
}

class _ConsoleVehicleVerifyState extends State<ConsoleVehicleVerify> {
  List<AppUser> _members = [];
  bool _loading = false;
  String? _error;

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
      final list = await context.read<ApiServices>().users.list(
            view: 'vehicle',
            limit: 100,
          );
      // 차량 사진이 있는 회원만 노출
      setState(() => _members = list.where((u) => u.vehiclePhoto.isNotEmpty).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(String email, bool approved) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ApiServices>().users.verifyVehicle(
            email: email,
            approved: approved,
          );
      await _load();
      messenger.showSnackBar(
        SnackBar(content: Text('${approved ? '승인' : '거절'} 처리되었습니다.')),
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
        title: const Text('차량 사진 인증'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _members.isEmpty && !_loading
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(_error ?? '대기 중인 차량 인증이 없습니다.'),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _card(_members[i]),
              ),
      ),
    );
  }

  Widget _card(AppUser u) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (u.vehiclePhoto.isNotEmpty)
              _photo(u.vehiclePhoto)
            else
              Container(
                height: 140,
                color: Colors.grey.shade100,
                child: const Center(child: Text('사진 없음')),
              ),
            const SizedBox(height: 12),
            Text(u.email, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (u.nickname.isNotEmpty) Text(u.nickname),
            if (u.vehicleNumber.isNotEmpty)
              Text('차량: ${u.vehicleNumber}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _verify(u.email, true),
                    child: const Text('차량 승인'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _verify(u.email, false),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('거절'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '※ 차량 승인/거절 처리 후 서버에서 사진은 즉시 삭제됩니다.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(String dataUrl) {
    try {
      final body = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
      final bytes = base64Decode(body);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          Uint8List.fromList(bytes),
          height: 220,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      );
    } catch (_) {
      return Container(
        height: 140,
        color: Colors.grey.shade100,
        child: const Center(child: Text('사진을 표시할 수 없음')),
      );
    }
  }
}
