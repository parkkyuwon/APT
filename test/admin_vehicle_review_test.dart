import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/screens/admin/console_members.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

void main() {
  testWidgets('matched OCR requires photo review before final member approval',
      (tester) async {
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
      final client = await ApiClient.init();
      await client.clearSession();
      final adapter = ControlledApi();
      client.dio.httpClientAdapter = adapter;
      addTearDown(adapter.close);
      await tester.pumpWidget(Provider.value(
          value: ApiServices.from(client),
          child: const MaterialApp(home: ConsoleMembers())));
      (await adapter.next()).reply(body: {
        'ok': true,
        'users': [
          {
            'email': 'pending@example.invalid',
            'name': 'Resident',
            'status': 'pending',
            'vehicleNumber': '123가4567',
            'profileComplete': true,
            'ocrMatched': true,
            'vehicleVerified': false,
            'vehicleSubmissionVersion': 3,
            'consentAt': '2026-10-20T00:00:00Z',
            'createdAt': '2026-10-20T00:00:00Z',
          }
        ]
      });
      for (var retry = 0; retry < 50; retry++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.text('pending@example.invalid').evaluate().isNotEmpty) break;
      }
      expect(
          tester
              .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, '사용자 승인'))
              .onPressed,
          isNull);
      expect(
          tester
              .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, '관리자 승인'))
              .onPressed,
          isNull);
      await tester.ensureVisible(find.text('사진 검토'));
      await tester.tap(find.text('사진 검토'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final review = await adapter.next();
      expect(review.options.method, 'GET');
      expect(review.options.path, '/api/users');
      expect(review.options.queryParameters['view'], 'vehicle');
      review.reply(body: {'ok': true, 'users': []});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
}
