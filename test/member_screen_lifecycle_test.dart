import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/screens/public/mypage_screen.dart';
import 'package:apt_ev_charging/screens/public/chat_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/controlled_api.dart';

void main() {
  testWidgets('returning from profile editing refreshes member information',
      (tester) async {
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
      final api = await ApiClient.init();
      await api.clearSession();
      final adapter = ControlledApi();
      api.dio.httpClientAdapter = adapter;
      final services = ApiServices.from(api);
      final auth = AuthProvider(services);
      addTearDown(adapter.close);
      addTearDown(auth.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: services),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(home: MypageScreen()),
      ));
      (await adapter.next())
          .reply(body: {'ok': true, 'user': null, 'history': []});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pump();
      await tester.tap(find.text('정보 수정'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final notices = await adapter.next();
      expect(notices.options.path, '/api/member-notices');
      notices.reply(body: {'ok': true, 'notices': []});
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final refresh = await adapter.next();
      expect(refresh.options.path, '/api/my-history');
      refresh.reply(body: {
        'ok': true,
        'user': {'name': 'Updated member'},
        'history': []
      });
      for (var retry = 0; retry < 50; retry++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.text('Updated member').evaluate().isNotEmpty) break;
      }
      expect(find.text('Updated member'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets('sending chat then leaving screen ignores the response',
      (tester) async {
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
      final api = await ApiClient.init();
      await api.clearSession();
      final adapter = ControlledApi();
      api.dio.httpClientAdapter = adapter;
      final services = ApiServices.from(api);
      final auth = AuthProvider(services);
      addTearDown(adapter.close);
      addTearDown(auth.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: services),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(home: ChatScreen()),
      ));
      (await adapter.next()).reply(body: {'ok': true, 'messages': []});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'local message');
      await tester.tap(find.byIcon(Icons.send));
      final request = await adapter.next();
      await tester.pumpWidget(const SizedBox.shrink());
      request.reply(body: {
        'ok': true,
        'message': {'id': 1, 'message': 'local message'}
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    expect(tester.takeException(), isNull);
  });
  for (final status in [200, 403]) {
    testWidgets('history response $status after leaving screen is ignored',
        (tester) async {
      await tester.runAsync(() async {
        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({});
        await AppConfig.init();
        final api = await ApiClient.init();
        await api.clearSession();
        final adapter = ControlledApi();
        api.dio.httpClientAdapter = adapter;
        final services = ApiServices.from(api);
        final auth = AuthProvider(services);
        addTearDown(adapter.close);
        addTearDown(auth.dispose);
        await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: services),
            ChangeNotifierProvider.value(value: auth),
          ],
          child: const MaterialApp(home: MypageScreen()),
        ));
        final request = await adapter.next();
        await tester.pumpWidget(const SizedBox.shrink());
        request.reply(
            status: status,
            body: status == 200
                ? {'ok': true, 'user': null, 'history': []}
                : {'ok': false, 'error': 'Denied'});
        // Drain the real Dio response chain outside the fake widget clock.
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      expect(tester.takeException(), isNull);
    });
  }
}
