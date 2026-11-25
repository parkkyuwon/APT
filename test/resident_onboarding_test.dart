import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:apt_ev_charging/core/errors.dart';
import 'package:apt_ev_charging/core/plate_recognition.dart';
import 'package:apt_ev_charging/models/session.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/widgets/vehicle_ocr_input.dart';

class DelayedRecognizer extends PlateRecognitionService {
  final result = Completer<List<String>>();
  @override
  Future<List<String>> recognize(String path) => result.future;
}

void main() {
  testWidgets('multiple typed plates disable OCR actions and invalidate result',
      (tester) async {
    VehicleOcrResult? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VehicleOcrInput(
      initialNumber: '123가4567',
      onChanged: (value) => result = value,
    ))));
    await tester.enterText(find.byType(TextField), '123가4567, 456나7890');
    await tester.pump();
    expect(
        tester
            .widgetList<OutlinedButton>(
                find.byWidgetPredicate((w) => w is OutlinedButton))
            .every((button) => button.onPressed == null),
        isTrue);
    expect(find.textContaining('여러 차량번호'), findsOneWidget);
    expect(result, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
      'photo-required API errors route to OCR while blocked errors remain blocked',
      () {
    expect(
        resolveAuthErrorStage(
            ApiException(
                statusCode: 403,
                message: 'photo required',
                needsPhotoVerification: true),
            AuthStage.anonymous),
        AuthStage.needsPhotoVerification);
    expect(
        resolveAuthErrorStage(
            ApiException(
                statusCode: 403,
                message: 'blocked',
                authStatus: AuthStatus.blocked,
                needsPhotoVerification: true),
            AuthStage.anonymous),
        AuthStage.blocked);
  });
  SessionInfo session(String status, {bool complete = false}) =>
      SessionInfo.fromJson({
        'email': 'resident@example.invalid',
        'status': status,
        'approved': status == 'approved',
        'profileComplete': complete,
      });
  test('restrictions precede every onboarding flag', () {
    for (final status in ['blocked', 'rejected', 'withdrawn', 'dormant']) {
      expect(
          resolveAuthStage(session(status),
              needsConsent: true, needsPhotoVerification: true),
          AuthStage.blocked);
    }
  });
  test('pending residents finish consent and OCR before approval queue', () {
    expect(resolveAuthStage(session('pending'), needsConsent: true),
        AuthStage.needsConsent);
    expect(resolveAuthStage(session('pending')), AuthStage.needsProfileSetup);
    expect(
        resolveAuthStage(session('pending', complete: true),
            needsPhotoVerification: true),
        AuthStage.needsPhotoVerification);
    expect(resolveAuthStage(session('pending', complete: true)),
        AuthStage.pending);
    expect(AuthStatus.pending, isNot(AuthStatus.approved));
  });
  testWidgets(
      'number edit discards in-flight matching OCR and cannot restore success',
      (tester) async {
    final recognizer = DelayedRecognizer();
    VehicleOcrResult? current;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VehicleOcrInput(
      initialNumber: '123가4567',
      recognizer: recognizer,
      pickImage: (_) async => XFile.fromData(
          base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='),
          mimeType: 'image/png'),
      onChanged: (value) => current = value,
    ))));
    await tester.tap(find.text('갤러리'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123나4567');
    recognizer.result.complete(['123가4567']);
    await tester.pump();
    expect(current, isNull);
    expect(find.textContaining('일치합니다.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
