import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/user.dart';
import '../../services/services.dart';

/// [console_vehicle_verify_k9r2m4x.html] — 제출된 차량 사진 검토.
class ConsoleVehicleVerify extends StatefulWidget {
  const ConsoleVehicleVerify({super.key, this.email});

  final String? email;

  @override
  State<ConsoleVehicleVerify> createState() => _ConsoleVehicleVerifyState();
}

class _ConsoleVehicleVerifyState extends State<ConsoleVehicleVerify> {
  List<AppUser> _members = [];
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
            view: 'vehicle',
            limit: 100,
          );
      // 차량 사진이 있는 회원만 노출
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _members = list
          .where((u) =>
              u.vehiclePhoto.isNotEmpty &&
              (widget.email == null || u.email == widget.email))
          .toList());
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

  Future<void> _verify(AppUser u, bool approved) async {
    if (_processing.contains(u.email)) return;
    setState(() => _processing.add(u.email));
    try {
      if (!approved) {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                  title: const Text('차량 인증 거절 확인'),
                  content: Text(
                      '${u.email}\n차량: ${u.vehicleNumber}\n제출 사진이 즉시 삭제되어 같은 사진을 다시 검토할 수 없습니다.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('취소')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('거절')),
                  ],
                ));
        if (confirmed != true) return;
      }
      if (!mounted) return;
      await context.read<ApiServices>().users.verifyVehicle(
            email: u.email,
            approved: approved,
            expectedMemberCreatedAt: u.createdAt,
            expectedVehicleSubmissionVersion: u.vehicleSubmissionVersion,
          );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${approved ? '승인' : '거절'} 처리되었습니다.')));
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
        title: const Text('차량 사진 인증'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
            child: RefreshIndicator(
          onRefresh: _load,
          child: _members.isEmpty && !_loading
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(_error ??
                          (widget.email == null
                              ? '대기 중인 차량 인증이 없습니다.'
                              : '선택한 회원의 제출 사진이 없습니다.')),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _card(_members[i]),
                ),
        )),
      ]),
    );
  }

  Widget _card(AppUser u) {
    final busy = _loading || _processing.contains(u.email);
    final canApprove = u.consentAt != null && u.ocrMatched;
    final reason = u.consentAt == null
        ? '약관 동의가 필요합니다.'
        : !u.ocrMatched
            ? '차량번호와 사진의 OCR 일치가 필요합니다.'
            : null;
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
            if (u.name.isNotEmpty) Text(u.name),
            if (u.nickname.isNotEmpty) Text('닉네임: ${u.nickname}'),
            Text(u.ocrMatched ? 'OCR 번호 일치 (관리자 최종 검토 필요)' : 'OCR 번호 미확인'),
            if (u.vehicleNumber.isNotEmpty)
              Text('차량: ${u.vehicleNumber}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (u.vehicleVerificationExempt)
              const Text('사진·OCR 면제 승인 (사진 인증과 별도)'),
            if (!u.vehicleVerificationRequired)
              const Text('사진·OCR 인증 선택: 최종 승인은 회원 승인에서 처리합니다.'),
            if (reason != null)
              Text(reason, style: const TextStyle(color: Colors.orange)),
            if (_processing.contains(u.email)) const Text('처리 중…'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        !busy && canApprove ? () => _verify(u, true) : null,
                    child: const Text('차량 승인'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _verify(u, false),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
          errorBuilder: (_, __, ___) => const SizedBox(
              height: 140, child: Center(child: Text('사진을 표시할 수 없음'))),
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
