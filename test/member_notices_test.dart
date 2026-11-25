import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/screens/onboarding/profile_setup_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

void main() {
  testWidgets('late notice response after leaving profile is ignored',
      (tester) async {
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
      final client = await ApiClient.init();
      await client.clearSession();
      final adapter = ControlledApi();
      client.dio.httpClientAdapter = adapter;
      final services = ApiServices.from(client);
      final auth = AuthProvider(services);
      addTearDown(adapter.close);
      addTearDown(auth.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: services),
          ChangeNotifierProvider.value(value: auth)
        ],
        child: const MaterialApp(home: ProfileSetupScreen()),
      ));
      final request = await adapter.next();
      await tester.pumpWidget(const SizedBox.shrink());
      request.reply(body: {
        'ok': true,
        'notices': [
          {'id': '1', 'message': 'late message'}
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    expect(tester.takeException(), isNull);
  });
  for (final status in [200, 503]) {
    testWidgets('profile notices $status leave information entry usable',
        (tester) async {
      await tester.runAsync(() async {
        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({});
        await AppConfig.init();
        final client = await ApiClient.init();
        await client.clearSession();
        final adapter = ControlledApi();
        client.dio.httpClientAdapter = adapter;
        final services = ApiServices.from(client);
        final auth = AuthProvider(services);
        addTearDown(adapter.close);
        addTearDown(auth.dispose);
        await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: services),
            ChangeNotifierProvider.value(value: auth)
          ],
          child: const MaterialApp(home: ProfileSetupScreen()),
        ));
        final request = await adapter.next();
        expect(request.options.path, '/api/member-notices');
        request.reply(
            status: status,
            body: status == 200
                ? {
                    'ok': true,
                    'notices': [
                      {
                        'id': 4,
                        'message': '차량 정보 입력을 부탁드립니다.',
                        'createdAt': '2026-10-14T00:00:00Z'
                      }
                    ]
                  }
                : {'ok': false, 'error': 'Unavailable'});
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.text('Google 표시 이름'), findsOneWidget);
        expect(
            tester
                .widgetList<TextFormField>(find.byType(TextFormField))
                .where((field) => field.enabled == false)
                .length,
            2);
        expect(
            tester
                .widgetList<TextField>(find.byType(TextField))
                .singleWhere((field) => field.decoration?.labelText == '차량번호')
                .enabled,
            isTrue);
        expect(find.text('승인 요청'), findsOneWidget);
        expect(find.text('닉네임'), findsOneWidget);
        expect(find.text('차량 정보 입력을 부탁드립니다.'),
            status == 200 ? findsOneWidget : findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
      expect(tester.takeException(), isNull);
    });
  }
}
