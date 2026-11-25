import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

String normalizePlate(String value) => value.replaceAll(RegExp(r'[\s-]'), '');

bool isSinglePlate(String value) => RegExp(
      r'^(?:(?:서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주))?\d{2,3}[가-힣]\d{4}$',
    ).hasMatch(normalizePlate(value));

List<String> extractPlateCandidates(String text) {
  final compact = normalizePlate(text);
  return RegExp(
          r'(?:(?:서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주))?\d{2,3}[가-힣]\d{4}')
      .allMatches(compact)
      .map((m) => m.group(0)!)
      .toSet()
      .toList();
}

bool plateMatches(String number, Iterable<String> candidates) {
  final normalized = normalizePlate(number);
  return isSinglePlate(number) &&
      candidates.any((c) => normalizePlate(c) == normalized);
}

/// On-device Korean recognizer. OCR is advisory; only an administrator approves.
class PlateRecognitionService {
  Future<List<String>> recognize(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      return extractPlateCandidates(result.text);
    } finally {
      await recognizer.close();
    }
  }
}
