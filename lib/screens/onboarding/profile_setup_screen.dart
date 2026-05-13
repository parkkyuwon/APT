import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/image_utils.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';

/// [profile.html](D:/vsCodeProg/APT-Prj/profile.html) 동등 화면.
///
/// - 최초 로그인 후 닉네임/차량번호/전화번호 입력이 필요할 때 (needsProfileSetup)
/// - 평시 "내 정보 수정" (isEdit=true) 모드도 동일 화면 사용
///
/// POST /api/profile 로 전송. vehicle photo 는 base64 data URL 로 전송.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.isEdit = false});

  final bool isEdit;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _vehicleNumber = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _picker = ImagePicker();

  String? _photoDataUrl;
  String _photoStatus = '';
  String? _error;
  bool _submitting = false;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _nickname.dispose();
    _vehicleNumber.dispose();
    _phoneNumber.dispose();
    super.dispose();
  }

  void _prefill() {
    final session = context.read<AuthProvider>().session;
    if (session != null) {
      _nickname.text = session.nickname;
      _vehicleNumber.text = session.vehicleNumber;
      _phoneNumber.text = session.phoneNumber;
    }
    setState(() => _initialLoaded = true);
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _photoStatus = '사진을 처리하는 중...');
      final bytes = await picked.readAsBytes();
      await _setPhotoBytes(bytes);
    } catch (e) {
      setState(() => _photoStatus = '사진 처리 중 오류: $e');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _photoStatus = '사진을 처리하는 중...');
      final bytes = await picked.readAsBytes();
      await _setPhotoBytes(bytes);
    } catch (e) {
      setState(() => _photoStatus = '사진 처리 중 오류: $e');
    }
  }

  Future<void> _setPhotoBytes(Uint8List bytes) async {
    final dataUrl = await encodeVehiclePhotoDataUrl(bytes);
    final kb = estimateBase64SizeKb(dataUrl);
    if (kb > 900) {
      setState(() {
        _photoStatus = '사진이 너무 큽니다 ($kb KB). 더 작은 사진을 선택해 주세요.';
        _photoDataUrl = null;
      });
      return;
    }
    setState(() {
      _photoDataUrl = dataUrl;
      _photoStatus = '업로드 준비 완료 ($kb KB) — 저장하기를 눌러야 전송됩니다.';
    });
  }

  void _clearPhoto() {
    setState(() {
      _photoDataUrl = null;
      _photoStatus = '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final services = context.read<ApiServices>();
    final auth = context.read<AuthProvider>();
    try {
      await services.profile.updateProfile(
        nickname: _nickname.text.trim(),
        vehicleNumber: _vehicleNumber.text.trim(),
        phoneNumber: _phoneNumber.text.trim(),
        vehiclePhotoBase64: _photoDataUrl,
      );
      // 저장 후 전체 세션/stage 재계산
      await auth.bootstrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장되었습니다.')),
      );
      if (widget.isEdit) {
        unawaited(Navigator.of(context).maybePop());
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? '내 정보 수정' : '프로필 입력'),
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isEdit
                      ? '닉네임, 차량번호, 전화번호를 직접 수정할 수 있습니다.'
                      : '서비스 이용을 위해 기본 정보를 입력해 주세요.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: auth.session?.email ?? '',
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: '로그인 계정',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nickname,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    hintText: '예: 101동 아이오닉',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? '닉네임을 입력하세요' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehicleNumber,
                  decoration: const InputDecoration(
                    labelText: '차량번호',
                    hintText: '예: 123가4567',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? '차량번호를 입력하세요' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneNumber,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '전화번호',
                    hintText: '예: 010-1234-5678',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true) ? '전화번호를 입력하세요' : null,
                ),
                const SizedBox(height: 24),
                const Text(
                  '차량 사진',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  '번호판이 잘 보이도록 촬영 — 관리자 검토 후 삭제됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _capturePhoto,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('카메라'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickPhoto,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('갤러리'),
                      ),
                    ),
                  ],
                ),
                if (_photoDataUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _decodeBase64(_photoDataUrl!),
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _submitting ? null : _clearPhoto,
                    child: const Text('사진 제거'),
                  ),
                ],
                if (_photoStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _photoStatus,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_submitting ? '저장 중...' : '저장하기'),
                ),
              ],
            ),
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
