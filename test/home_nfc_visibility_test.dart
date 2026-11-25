import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/app_route_observer.dart';
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

  testWidgets('a tag waits while a confirmation dialog covers the home',
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
      final navigator = GlobalKey<NavigatorState>();
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
          'vehicleNumber': '12가3456',
        },
      });
      await bootstrap;
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: app),
        ],
        child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [appRouteObserver],
            home: const HomeScreen()),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      (await transport.next()).reply();
      await app.refresh();
      await tester.pump();
      final dialog = showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(title: Text('편집 확인')),
      );
      await tester.pump();
      final before = transport.pending.length;
      DeepLink.setPendingSlot('fast50-1');
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
      }
      expect(transport.pending.length, before,
          reason: 'Hidden home must neither refresh nor write parking');
      expect(DeepLink.hasPendingSlot, isTrue);
      navigator.currentState!.pop();
      await dialog;
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
      }
      final refresh = await transport.next();
      expect(refresh.options.method, 'GET');
      refresh.reply(status: 403, body: {'ok': false, 'error': 'Retry later'});
      await app.refresh();
      await tester.pump();
      expect(
          transport.pending
              .where((request) => request.options.method == 'POST'),
          isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('a tag stays pending when the app pauses during its state read',
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
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final bootstrap = auth.bootstrap();
      (await transport.next()).reply(body: {
        'ok': true,
        'session': {
          'email': 'member@example.test',
          'role': 'user',
          'status': 'approved',
          'approved': true,
          'profileComplete': true,
          'vehicleNumber': '12가3456',
        },
      });
      await bootstrap;
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: app),
        ],
        child: MaterialApp(
            navigatorObservers: [appRouteObserver], home: const HomeScreen()),
      ));
      await tester.pump();
      (await transport.next()).reply();
      await app.refresh();
      await tester.pump();
      DeepLink.setPendingSlot('fast50-1');
      final read = await transport.next();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      read.reply(status: 403, body: {'ok': false, 'error': 'Retry later'});
      await app.refresh();
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
      }
      expect(DeepLink.hasPendingSlot, isTrue,
          reason:
              'Paused home must keep the tag instead of processing the response');
      expect(
          transport.pending
              .where((request) => request.options.method == 'POST'),
          isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      app.stop();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });
}
