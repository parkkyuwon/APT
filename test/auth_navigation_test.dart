import 'dart:async';

import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/deep_link.dart';
import 'package:apt_ev_charging/main.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/screens/login_screen.dart';
import 'package:apt_ev_charging/screens/public/home_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/controlled_api.dart';

void main() {
  testWidgets(
      'incoming voice controls remain visible above a pushed member route',
      (tester) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
      final client = await ApiClient.init();
      await client.clearSession();
      final transport = ControlledApi();
      client.dio.httpClientAdapter = transport;
      addTearDown(transport.close);
      await tester.pumpWidget(AptEvApp(services: ApiServices.from(client)));
      final auth =
          tester.element(find.byType(MaterialApp)).read<AuthProvider>();
      final restored = Completer<void>();
      void onAuth() {
        if (auth.stage == AuthStage.approved && !restored.isCompleted) {
          restored.complete();
        }
      }

      auth.addListener(onAuth);
      (await transport.next()).reply(body: {
        'ok': true,
        'session': {
          'email': 'owner@example.invalid',
          'nickname': 'Owner',
          'role': 'user',
          'status': 'approved',
          'approved': true,
          'profileComplete': true,
        }
      });
      await restored.future.timeout(const Duration(seconds: 3));
      auth.removeListener(onAuth);
      await tester.pump();
      final context = tester.element(find.byType(HomeScreen));
      final stateRead = context.read<AppStateProvider>().refresh();
      PendingRequest? inbox;
      final seen = <String>{};
      for (var i = 0; i < 4; i++) {
        final request = await transport.next();
        if (request.options.path == '/api/state') {
          seen.add('state');
          request.reply();
        } else if (request.options.path == '/api/indoor-positioning') {
          seen.add('indoor');
          request.reply(body: {
            'ok': true,
            'dataset': {
              'schemaVersion': 1,
              'revision': 0,
              'enabled': false,
              'siteId': 'home',
              'mapVersion': 'simplified-v1',
              'surveys': [],
              'beaconPositions': {}
            }
          });
        } else {
          expect(request.options.path, '/api/parking-voice');
          final action = request.options.queryParameters['action'];
          expect(['capability', 'inbox'], contains(action));
          seen.add('$action');
          if (action == 'capability') {
            request.reply(body: {'ok': true, 'enabled': true});
          } else {
            inbox = request;
          }
        }
      }
      expect(seen, {'state', 'capability', 'inbox', 'indoor'});
      await stateRead;
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Text('pushed-member-content')))));
      await tester.pumpAndSettle();
      inbox!.reply(body: {
        'ok': true,
        'calls': [
          {
            'id': 'ringing-only',
            'status': 'ringing',
            'isCaller': false,
            'slotName': '지하 주차면',
            'peerNickname': 'Caller',
            'ringExpiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(seconds: 30))
                .toIso8601String(),
          }
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('pushed-member-content'), findsOneWidget);
      expect(find.text('지하 주차면 관련 통화 요청'), findsOneWidget);
      expect(find.text('수락'), findsOneWidget);
      expect(find.text('거절'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'a cold slot link opens the auth root without a named route error',
      (tester) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/index.html?slot=slow7-1';
    addTearDown(() {
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue();
      DeepLink.stop();
      DeepLink.consumePendingSlot();
    });
    DeepLink.start();
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
      final client = await ApiClient.init();
      await client.clearSession();
      final transport = ControlledApi();
      client.dio.httpClientAdapter = transport;
      addTearDown(transport.close);
      await tester.pumpWidget(AptEvApp(services: ApiServices.from(client)));
      expect(tester.takeException(), isNull);
      expect(DeepLink.consumePendingSlot(), 'slow7-1');
      final auth =
          tester.element(find.byType(MaterialApp)).read<AuthProvider>();
      final restored = Completer<void>();
      void onAuth() {
        if (auth.stage == AuthStage.anonymous && !restored.isCompleted) {
          restored.complete();
        }
      }

      auth.addListener(onAuth);
      (await transport.next()).reply(body: {'ok': true, 'session': null});
      await restored.future.timeout(const Duration(seconds: 3));
      auth.removeListener(onAuth);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('logout removes routes belonging to the previous member',
      (tester) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await AppConfig.init();
      final client = await ApiClient.init();
      await client.clearSession();
      final transport = ControlledApi();
      addTearDown(transport.close);
      client.dio.httpClientAdapter = transport;
      await tester.pumpWidget(AptEvApp(services: ApiServices.from(client)));
      final auth =
          tester.element(find.byType(MaterialApp)).read<AuthProvider>();
      final restored = Completer<void>();
      void onAuth() {
        if (auth.stage == AuthStage.approved && !restored.isCompleted) {
          restored.complete();
        }
      }

      auth.addListener(onAuth);
      (await transport.next()).reply(body: {
        'ok': true,
        'session': {
          'email': 'member@example.test',
          'role': 'user',
          'status': 'approved',
          'approved': true,
          'profileComplete': true,
        }
      });
      await restored.future.timeout(const Duration(seconds: 3));
      auth.removeListener(onAuth);
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
      final initialState = tester
          .element(find.byType(HomeScreen))
          .read<AppStateProvider>()
          .refresh();
      final seen = <String>{};
      for (var i = 0; i < 3; i++) {
        final request = await transport.next();
        seen.add(request.options.path);
        if (request.options.path == '/api/parking-voice') {
          expect(request.options.queryParameters['action'], 'capability');
          request.reply(body: {
            'ok': true,
            'enabled': false,
            'reason': 'TURN_NOT_CONFIGURED'
          });
        } else if (request.options.path == '/api/indoor-positioning') {
          request.reply(body: {
            'ok': true,
            'dataset': {
              'schemaVersion': 1,
              'revision': 0,
              'enabled': false,
              'siteId': 'home',
              'mapVersion': 'simplified-v1',
              'surveys': [],
              'beaconPositions': {}
            }
          });
        } else {
          expect(request.options.path, '/api/state');
          request.reply();
        }
      }
      expect(seen,
          {'/api/parking-voice', '/api/state', '/api/indoor-positioning'});
      await initialState;
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
      }
      final context = tester.element(find.byType(HomeScreen));
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('previous-member-route')),
      )));
      await tester.pumpAndSettle();
      expect(find.text('previous-member-route'), findsOneWidget);
      final logout = auth.logout();
      (await transport.next()).reply();
      await logout;
      await tester.pumpAndSettle();
      expect(find.text('previous-member-route'), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
