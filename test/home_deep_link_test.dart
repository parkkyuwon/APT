import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/deep_link.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/screens/public/home_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final warm in [false, true]) {
    testWidgets(
        '${warm ? 'warm' : 'cold'} slot link never writes when fresh state fetch fails',
        (tester) async {
      await tester.runAsync(() async {
        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({});
        await AppConfig.init();
        final client = await ApiClient.init();
        await client.clearSession();
        final transport = ControlledApi();
        client.dio.httpClientAdapter = transport;
        final services = ApiServices.from(client);
        final auth = AuthProvider(services);
        final app = AppStateProvider(services, auth: auth);
        addTearDown(() {
          app.dispose();
          auth.dispose();
          transport.close();
          DeepLink.consumePendingSlot();
        });

        final bootstrap = auth.bootstrap();
        (await transport.next()).reply(body: {
          'ok': true,
          'session': {
            'email': 'member@example.test',
            'role': 'user',
            'status': 'approved',
            'approved': true,
            'profileComplete': true,
            'vehicleNumber': 'test-car',
          }
        });
        await bootstrap;
        if (!warm) DeepLink.setPendingSlot('fast50-1');
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: app),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ));
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        final initial = await transport.next();
        initial.reply();
        if (warm) {
          await app.refresh();
          DeepLink.setPendingSlot('fast50-1');
        }
        for (var i = 0; i < 4; i++) {
          await tester.pump();
        }
        final refresh = await transport.next();
        expect(refresh.options.path, '/api/state');
        refresh.reply(
            status: 403, body: {'ok': false, 'error': 'State unavailable'});
        await app.refresh();
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(Duration.zero);
          await tester.pump();
        }
        expect(transport.pending.where((r) => r.options.method == 'POST'),
            isEmpty);
        expect(find.textContaining('State unavailable'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });
  }
}
