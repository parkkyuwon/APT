import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/plate_recognition.dart';

class VehicleOcrResult {
  const VehicleOcrResult(this.number, this.photoDataUrl, this.candidates);
  final String number;
  final String photoDataUrl;
  final List<String> candidates;
}

/// Shared comparison UI; never writes profile or approval data by itself.
class VehicleOcrInput extends StatefulWidget {
  const VehicleOcrInput(
      {super.key,
      this.initialNumber = '',
      required this.onChanged,
      this.onNumberChanged,
      this.enabled = true,
      this.recognizer,
      this.pickImage});
  final String initialNumber;
  final ValueChanged<VehicleOcrResult?> onChanged;
  final ValueChanged<String>? onNumberChanged;
  final bool enabled;
  final PlateRecognitionService? recognizer;
  final Future<XFile?> Function(ImageSource source)? pickImage;
  @override
  State<VehicleOcrInput> createState() => _VehicleOcrInputState();
}

class _VehicleOcrInputState extends State<VehicleOcrInput> {
  late final TextEditingController _number;
  Uint8List? _bytes;
  String? _dataUrl;
  List<String> _candidates = [];
  String _message = '';
  bool _busy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: widget.initialNumber);
  }

  @override
  void dispose() {
    _generation++;
    _number.dispose();
    super.dispose();
  }

  void _invalidateNumber(String number) {
    _generation++;
    setState(() {
      _candidates = [];
      _busy = false;
      _message = isSinglePlate(number)
          ? '차량번호가 변경되었습니다. 사진을 다시 선택해 비교해 주세요.'
          : '차량번호 한 개만 정확히 입력해 주세요. 여러 차량번호는 등록할 수 없습니다.';
    });
    widget.onChanged(null);
    widget.onNumberChanged?.call(number);
  }

  Future<void> _pick(ImageSource source) async {
    if (!isSinglePlate(_number.text)) {
      setState(() => _message = '차량번호 한 개만 정확히 입력한 뒤 사진을 선택해 주세요.');
      widget.onChanged(null);
      return;
    }
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _candidates = [];
      _dataUrl = null;
      _bytes = null;
      _message = '';
    });
    widget.onChanged(null);
    try {
      final image = await (widget.pickImage?.call(source) ??
          ImagePicker().pickImage(
              source: source,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 85));
      if (!mounted || generation != _generation) return;
      if (image == null) {
        setState(() => _message = '사진 선택이 취소되었습니다.');
        return;
      }
      final bytes = await image.readAsBytes();
      if (!mounted || generation != _generation) return;
      if (bytes.length > 900 * 1024) {
        throw StateError('사진은 900KB 이하여야 합니다. 더 작은 사진을 선택해 주세요.');
      }
      String? mime;
      if (bytes.length >= 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71) {
        mime = 'image/png';
      }
      if (bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255) {
        mime = 'image/jpeg';
      }
      if (bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
        mime = 'image/webp';
      }
      if (mime == null) throw StateError('PNG, JPEG, WebP 사진을 선택해 주세요.');
      setState(() {
        _bytes = bytes;
        _message = '번호판을 인식하는 중...';
      });
      final candidates = await (widget.recognizer ?? PlateRecognitionService())
          .recognize(image.path);
      if (!mounted || generation != _generation) return;
      final matched = plateMatches(_number.text, candidates);
      setState(() {
        _dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
        _candidates = candidates;
        _message = candidates.isEmpty
            ? '번호판을 인식하지 못했습니다. 밝고 선명한 사진으로 다시 촬영해 주세요.'
            : matched
                ? '차량번호가 일치합니다. 최종 승인은 관리자가 진행합니다.'
                : '입력한 차량번호와 일치하지 않습니다. 번호와 사진을 확인해 주세요.';
      });
      widget.onChanged(matched
          ? VehicleOcrResult(normalizePlate(_number.text), _dataUrl!,
              List.unmodifiable(candidates))
          : null);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _message = '인식 실패: $e');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
            controller: _number,
            enabled: widget.enabled,
            onChanged: _invalidateNumber,
            decoration: const InputDecoration(
                labelText: '차량번호',
                hintText: '123가4567',
                border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed:
                      widget.enabled && !_busy && isSinglePlate(_number.text)
                          ? () => _pick(ImageSource.camera)
                          : null,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('카메라'))),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed:
                      widget.enabled && !_busy && isSinglePlate(_number.text)
                          ? () => _pick(ImageSource.gallery)
                          : null,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리'))),
        ]),
        if (_bytes != null)
          Image.memory(_bytes!,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('사진 미리보기를 표시할 수 없습니다.')),
        if (_busy) const LinearProgressIndicator(),
        if (_candidates.isNotEmpty) Text('인식 후보: ${_candidates.join(', ')}'),
        if (_message.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message)),
      ]);
}
