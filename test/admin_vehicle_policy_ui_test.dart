import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/screens/admin/console_members.dart';
import 'package:apt_ev_charging/screens/admin/console_vehicle_verify.dart';
import 'package:apt_ev_charging/screens/admin/console_operations.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

Map<String, dynamic> member([Map<String, dynamic> overrides = const {}]) => {
      'email': 'resident@example.invalid',
      'status': 'pending',
      'nickname': '입주민',
      'vehicleNumber': '123가4567',
      'profileComplete': true,
      'consentAt': '2026-10-20T00:00:00Z',
      'createdAt': '2026-10-20T00:00:00Z',
      'vehicleSubmissionVersion': 3,
      ...overrides,
    };
Future<ControlledApi> open(WidgetTester tester, Widget screen,
    List<Map<String, dynamic>> users) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  await AppConfig.init();
  final client = await ApiClient.init();
  await client.clearSession();
  final adapter = ControlledApi();
  client.dio.httpClientAdapter = adapter;
  addTearDown(adapter.close);
  await tester.pumpWidget(Provider.value(
      value: ApiServices.from(client), child: MaterialApp(home: screen)));
  (await adapter.next()).reply(body: {'ok': true, 'users': users});
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump();
    if (find.text('resident@example.invalid').evaluate().isNotEmpty) break;
  }
  return adapter;
}

void main() {
  testWidgets('operation policy save preserves state version and server result',
      (tester) async {
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
      final client = await ApiClient.init();
      await client.clearSession();
      final api = ControlledApi();
      client.dio.httpClientAdapter = api;
      final services = ApiServices.from(client);
      final auth = AuthProvider(services);
      final bootstrap = auth.bootstrap();
      (await api.next()).reply(body: {
        'ok': true,
        'session': {
          'email': 'admin@example.invalid',
          'status': 'approved',
          'role': 'admin',
          'approved': true,
          'profileComplete': true,
        }
      });
      await bootstrap;
      final app = AppStateProvider(services, auth: auth);
      addTearDown(() {
        app.dispose();
        auth.dispose();
        api.close();
      });
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: app, child: const MaterialApp(home: ConsoleOperations())));
      (await api.next()).reply(body: {
        'ok': true,
        'state': {'stateVersion': 7, 'vehicleVerificationRequired': true}
      });
      for (var retry = 0; retry < 50 && app.state.stateVersion != 7; retry++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      await tester.tap(find.text('차량 사진·OCR 인증 필수'));
      await tester.pump();
      final save = await api.next();
      expect(save.options.data['stateVersion'], 7);
      expect(save.options.data['vehicleVerificationRequired'], false);
      expect(
          tester
              .widget<SwitchListTile>(
                  find.widgetWithText(SwitchListTile, '차량 사진·OCR 인증 필수'))
              .onChanged,
          isNull);
      save.reply(body: {
        'ok': true,
        'state': {'stateVersion': 8, 'vehicleVerificationRequired': false}
      });
      for (var retry = 0; retry < 50 && app.state.stateVersion != 8; retry++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      expect(app.state.vehicleVerificationRequired, false);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'existing exemption stays distinct from photo approval when policy ON',
      (tester) async {
    await tester.runAsync(() async {
      await open(tester, const ConsoleMembers(), [
        member({'status': 'approved', 'vehicleVerificationExempt': true})
      ]);
      expect(find.text('승인 · 사진 인증 면제'), findsOneWidget);
      expect(
          tester
              .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, '사용자 승인'))
              .onPressed,
          isNotNull);
      expect(find.text('차량승인 취소'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
  testWidgets(
      'selected member review filters unrelated photos and guards repeated approval',
      (tester) async {
    await tester.runAsync(() async {
      final api = await open(tester,
          const ConsoleVehicleVerify(email: 'resident@example.invalid'), [
        member({'vehiclePhoto': 'invalid-photo', 'ocrMatched': true}),
        member({
          'email': 'unrelated@example.invalid',
          'vehiclePhoto': 'invalid-photo',
          'ocrMatched': true
        }),
      ]);
      expect(find.text('unrelated@example.invalid'), findsNothing);
      await tester.ensureVisible(find.text('차량 승인'));
      await tester.tap(find.text('차량 승인'));
      await tester.pump();
      final request = await api.next();
      expect(request.options.data['email'], 'resident@example.invalid');
      expect(request.options.data['expectedVehicleSubmissionVersion'], 3);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, '차량 승인'))
              .onPressed,
          isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      request.reply(body: {'ok': true});
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(api.pending.length, 2);
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'OFF policy permits final approval without inventing photo verification',
      (tester) async {
    await tester.runAsync(() async {
      final api = await open(tester, const ConsoleMembers(), [
        member({'vehicleVerificationRequired': false})
      ]);
      expect(
          tester
              .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, '사용자 승인'))
              .onPressed,
          isNotNull);
      await tester.tap(find.text('사용자 승인'));
      await tester.pump();
      final request = await api.next();
      expect(request.options.data['status'], 'approved');
      expect(request.options.data['expectedVehicleSubmissionVersion'], 3);
      expect(
          tester
              .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, '사용자 승인'))
              .onPressed,
          isNull);
      request.reply(body: {'ok': true});
      (await api.next()).reply(body: {'ok': true, 'users': []});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
  testWidgets('required photo review explains unavailable approval',
      (tester) async {
    await tester.runAsync(() async {
      await open(tester, const ConsoleMembers(), [member()]);
      expect(find.textContaining('차량 사진 검토'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
  testWidgets('block confirmation can be cancelled without request',
      (tester) async {
    await tester.runAsync(() async {
      final api = await open(tester, const ConsoleMembers(), [member()]);
      await tester.tap(find.widgetWithText(OutlinedButton, '차단'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('resident@example.invalid'), findsWidgets);
      await tester.tap(find.text('취소'));
      await tester.pump();
      expect(api.pending.length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
  testWidgets('vehicle review loading is visible', (tester) async {
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
      final client = await ApiClient.init();
      await client.clearSession();
      final api = ControlledApi();
      client.dio.httpClientAdapter = api;
      addTearDown(api.close);
      await tester.pumpWidget(Provider.value(
          value: ApiServices.from(client),
          child: const MaterialApp(home: ConsoleVehicleVerify())));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      (await api.next())
          .reply(status: 400, body: {'ok': false, 'error': '조회 실패'});
      for (var retry = 0; retry < 50; retry++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.textContaining('조회 실패').evaluate().isNotEmpty) break;
      }
      expect(find.textContaining('조회 실패'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
