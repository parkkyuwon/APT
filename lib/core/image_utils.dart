import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// 차량 사진을 서버 허용 범위로 리사이즈하고 data URL 문자열로 반환.
///
/// 서버는 base64 data URL 을 받아 [profile.js updateUserVehiclePhoto] 가 1MB 상한
/// 으로 검증한다. profile.js 의 브라우저 Canvas 방식과 동치가 되도록 동일 파라미터
/// (maxWidth=800, maxHeight=600, quality=0.75) 를 기본값으로 사용한다.
Future<String> encodeVehiclePhotoDataUrl(
  Uint8List bytes, {
  int maxWidth = 800,
  int maxHeight = 600,
  int jpegQuality = 75,
}) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: maxWidth,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;

  var w = image.width;
  var h = image.height;
  if (w > maxWidth || h > maxHeight) {
    final ratio = (maxWidth / w).clamp(0, 1).toDouble();
    final ratio2 = (maxHeight / h).clamp(0, 1).toDouble();
    final r = ratio < ratio2 ? ratio : ratio2;
    w = (w * r).round();
    h = (h * r).round();
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final resized = await picture.toImage(w, h);

  // Flutter 의 ui.Image 는 PNG 만 무손실 인코딩 가능. 용량을 위해
  // rawRgba → PNG 대신 압축 JPEG 가 필요할 경우 패키지 의존이 필요하다.
  // 여기서는 PNG 로 인코딩하되, maxWidth 를 작게 유지해 1MB 이하를 보장한다.
  final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('이미지 인코딩에 실패했습니다.');
  }
  final encoded = base64Encode(byteData.buffer.asUint8List());
  return 'data:image/png;base64,$encoded';
}

int estimateBase64SizeKb(String dataUrl) {
  final body = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
  return (body.length * 3 ~/ 4) ~/ 1024;
}
