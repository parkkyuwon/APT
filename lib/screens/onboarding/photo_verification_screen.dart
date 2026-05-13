import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/image_utils.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';

/// 차량 사진 재인증 화면.
///
/// `needsPhotoVerification` 플래그가 서버에서 내려올 때 노출 ([profile.js]
/// `photoVerificationMode`). 차량 사진만 재업로드하여 관리자 검토 대기 상태로 이동.
class PhotoVerificationScreen extends StatefulWidget {
  const PhotoVerificationScreen({super.key});

  @override
  State<PhotoVerificationScreen> createState() => _PhotoVerificationScreenState();
}

class _PhotoVerificationScreenState extends State<PhotoVerificationScreen> {
  final _picker = ImagePicker();
  String? _dataUrl;
  String _status = '';
  bool _submitting = false;
  bool _done = false;
  String? _error;

  Future<void> _pick({required ImageSource source}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _status = '사진을 처리하는 중...');
      final bytes = await picked.readAsBytes();
      final url = await encodeVehiclePhotoDataUrl(bytes);
      final kb = estimateBase64SizeKb(url);
      if (kb > 900) {
        setState(() {
          _dataUrl = null;
          _status = '사진이 너무 큽니다 ($kb KB). 더 작은 사진을 선택해 주세요.';
        });
        return;
      }
      setState(() {
        _dataUrl = url;
        _status = '업로드 준비 완료 ($kb KB)';
      });
    } catch (e) {
      setState(() => _status = '사진 처리 중 오류: $e');
    }
  }

  Future<void> _submit() async {
    if (_dataUrl == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final services = context.read<ApiServices>();
    final auth = context.read<AuthProvider>();
    try {
      await services.profile.updateProfile(
        nickname: auth.session?.nickname ?? '',
        vehicleNumber: auth.session?.vehicleNumber ?? '',
        phoneNumber: auth.session?.phoneNumber ?? '',
        vehiclePhotoBase64: _dataUrl,
      );
      setState(() => _done = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('차량 사진 인증'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: auth.logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.amber.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '차량 사진 재인증이 필요합니다.\n'
                    '번호판이 잘 보이도록 촬영한 사진을 업로드해 주세요. '
                    '관리자 검토 후 서비스 이용이 가능합니다.',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_done)
                const Card(
                  color: Color(0xFFE8F5E9),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '차량 사진이 전송되었습니다.\n'
                      '관리자 검토가 완료되면 자동으로 서비스를 이용할 수 있습니다.',
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : () => _pick(source: ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('카메라'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : () => _pick(source: ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('갤러리'),
                      ),
                    ),
                  ],
                ),
                if (_dataUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _decodeBase64(_dataUrl!),
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_status, style: const TextStyle(color: Colors.black54)),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_submitting || _dataUrl == null) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_submitting ? '전송 중...' : '사진 전송'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Uint8List _decodeBase64(String dataUrl) {
    final body = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    return Uri.parse('data:application/octet-stream;base64,$body').data!.contentAsBytes();
  }
}
