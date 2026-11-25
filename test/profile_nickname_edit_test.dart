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
  testWidgets(
      'approved nickname-only edit omits photo; replacement plate requires OCR',
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
      final services = ApiServices.from(client);
      final auth = AuthProvider(services);
      addTearDown(auth.dispose);
      final session = <String, dynamic>{
        'email': 'resident@example.invalid',
        'name': 'Google Name',
        'nickname': '기존 별명',
        'vehicleNumber': '123가4567',
        'role': 'user',
        'status': 'approved',
        'approved': true,
        'profileComplete': true
      };
      final boot = auth.bootstrap();
      (await adapter.next()).reply(body: {'ok': true, 'session': session});
      await boot;
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: services),
            ChangeNotifierProvider.value(value: auth)
          ],
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const ProfileSetupScreen(isEdit: true))),
                          child: const Text('edit')))))));
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      (await adapter.next()).reply(body: {'ok': true, 'notices': []});
      final nickname = find.byType(TextFormField).last;
      await tester.enterText(nickname, '새 별명');
      final plate = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '차량번호');
      await tester.enterText(plate, '234나5678');
      await tester.pump();
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
      await tester.enterText(plate, '123 가-4567');
      await tester.pump();
      await tester.ensureVisible(find.text('저장하기'));
      await tester.tap(find.text('저장하기'));
      final save = await adapter.next();
      expect(
          save.options.data, {'nickname': '새 별명', 'vehicleNumber': '123가4567'});
      save.reply(body: {
        'ok': true,
        'profile': {...session, 'nickname': '새 별명'}
      });
      final refreshed = await adapter.next();
      refreshed.reply(body: {
        'ok': true,
        'session': {...session, 'nickname': '새 별명'}
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(auth.session?.nickname, '새 별명');
      expect(auth.stage, AuthStage.approved);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
}
