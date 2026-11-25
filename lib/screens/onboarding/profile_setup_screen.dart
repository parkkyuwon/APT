import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/member_notice.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';
import '../../widgets/vehicle_ocr_input.dart';
import '../../core/plate_recognition.dart';
import '../../core/errors.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.isEdit = false});
  final bool isEdit;
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with WidgetsBindingObserver {
  VehicleOcrResult? _result;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late final String _originalVehicle;
  late String _number;
  bool _submitting = false;
  String? _error;
  List<MemberNotice> _notices = [];

  @override
  void initState() {
    super.initState();
    final session = context.read<AuthProvider>().session;
    _nickname = TextEditingController(text: session?.nickname ?? '');
    _originalVehicle = normalizePlate(session?.vehicleNumber ?? '');
    _number = _originalVehicle;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadNotices());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nickname.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_loadNotices());
  }

  Future<void> _loadNotices() async {
    final auth = context.read<AuthProvider>();
    final email = auth.session?.email;
    try {
      final notices = await context.read<ApiServices>().memberNotices.list();
      if (mounted && auth.session?.email == email) {
        setState(() => _notices = notices);
      }
    } catch (_) {/* Notices must not block profile completion. */}
  }

  Future<void> _submit() async {
    final result = _result;
    if (_submitting || !_canSave || !_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final email = auth.session?.email;
    final services = context.read<ApiServices>();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final requiresPhoto = auth.session?.vehicleVerificationRequired ?? true;
      await services.profile.updateProfile(
          nickname: _nickname.text.trim(),
          vehicleNumber: normalizePlate(_number),
          vehiclePhotoBase64: requiresPhoto ? result?.photoDataUrl : null,
          ocrCandidates: requiresPhoto ? result?.candidates : null);
      if (!mounted || auth.session?.email != email) return;
      if (widget.isEdit) Navigator.of(context).pop();
      await auth.bootstrap();
    } catch (e) {
      if (mounted && auth.session?.email == email) {
        setState(() => _error = '$e');
        // Another administrator may have restored the photo requirement while
        // this form was open. Re-read policy instead of leaving an unusable form.
        if (e is ApiException && [400, 409].contains(e.statusCode)) {
          await auth.bootstrap();
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _nicknameOnly =>
      widget.isEdit &&
      context.read<AuthProvider>().session?.approved == true &&
      normalizePlate(_number) == _originalVehicle &&
      isSinglePlate(_number);
  bool get _canSave =>
      isSinglePlate(_number) &&
      (_result != null ||
          _nicknameOnly ||
          context.read<AuthProvider>().session?.vehicleVerificationRequired ==
              false);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final requiresPhoto = auth.session?.vehicleVerificationRequired ?? true;
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.isEdit ? '내 정보 수정' : '차량번호 확인'), actions: [
        IconButton(
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃'),
      ]),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_notices.isNotEmpty)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('관리자 안내'),
                                    ..._notices.map((n) => Text(n.message)),
                                  ]))),
                    TextFormField(
                        initialValue: auth.session?.email ?? '',
                        enabled: false,
                        decoration: const InputDecoration(labelText: '로그인 계정')),
                    TextFormField(
                        initialValue: auth.session?.name ?? '',
                        enabled: false,
                        decoration:
                            const InputDecoration(labelText: 'Google 표시 이름')),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _nickname,
                        enabled: !_submitting,
                        maxLength: 30,
                        decoration: const InputDecoration(
                            labelText: '닉네임', border: OutlineInputBorder()),
                        validator: (value) => value == null ||
                                value.trim().isEmpty ||
                                value.trim().length > 30
                            ? '닉네임을 1~30자로 입력해 주세요.'
                            : null),
                    const SizedBox(height: 16),
                    Text(requiresPhoto
                        ? '차량번호는 한 계정에 한 개만 등록합니다. 번호를 변경하면 기존 차량을 대체하며, 새 번호판 사진 OCR 비교와 관리자 재승인이 필요합니다. 사진은 검토 후 삭제됩니다. 닉네임만 수정하면 기존 승인은 유지됩니다.'
                        : '현재 차량 사진·OCR 인증은 생략됩니다. 차량번호 한 개를 입력하고 관리자 승인을 받아 주세요. 차량번호를 변경하면 재승인이 필요하며, 닉네임만 수정하면 기존 승인은 유지됩니다.'),
                    const SizedBox(height: 16),
                    if (requiresPhoto)
                      VehicleOcrInput(
                          key: ValueKey('ocr-$_originalVehicle'),
                          initialNumber: _number,
                          enabled: !_submitting,
                          onNumberChanged: (number) =>
                              setState(() => _number = number),
                          onChanged: (result) =>
                              setState(() => _result = result))
                    else
                      TextFormField(
                          key: const ValueKey('vehicle-number-without-photo'),
                          initialValue: _number,
                          enabled: !_submitting,
                          decoration: const InputDecoration(
                              labelText: '차량번호',
                              hintText: '예: 123가4567',
                              border: OutlineInputBorder()),
                          onChanged: (value) => setState(() {
                                _number = value;
                                _result = null;
                              }),
                          validator: (value) => isSinglePlate(value ?? '')
                              ? null
                              : '차량번호 한 개만 정확히 입력해 주세요.'),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: _submitting || !_canSave ? null : _submit,
                        child: Text(_submitting
                            ? '전송 중...'
                            : _nicknameOnly && _result == null
                                ? '저장하기'
                                : '승인 요청')),
                  ]))),
    );
  }
}
