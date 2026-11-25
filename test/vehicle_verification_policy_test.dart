import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/models/app_state.dart';
import 'package:apt_ev_charging/models/session.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/screens/onboarding/profile_setup_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:apt_ev_charging/widgets/vehicle_ocr_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

void main() {
  test('state policy accepts only explicit false and survives cache roundtrip',
      () {
    for (final value in [null, true, 'false', 0]) {
      expect(
          AppState.fromJson({'vehicleVerificationRequired': value})
              .toJson()['vehicleVerificationRequired'],
          isTrue);
    }
    final state = AppState.fromJson({'vehicleVerificationRequired': false});
    expect(
        AppState.fromJson(state.toJson())
            .toJson()['vehicleVerificationRequired'],
        isFalse);
  });

  test('bootstrap policy overrides stale session policy and survives restore',
      () {
    final session = AuthBootstrap.fromJson({
      'vehicleVerificationRequired': false,
      'session': {'vehicleVerificationRequired': true}
    }).session!;
    expect(
        SessionInfo.fromJson(session.toJson())
            .toJson()['vehicleVerificationRequired'],
        isFalse);
    expect(SessionInfo.fromJson({}).toJson()['vehicleVerificationRequired'],
        isTrue);
  });

  for (final scenario in [(false, false), (true, false), (false, true)]) {
    final editing = scenario.$1;
    final policyChanged = scenario.$2;
    testWidgets(
        'optional photo policy submits ${editing ? 'replacement vehicle' : 'new profile'}; changed policy=$policyChanged',
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
          'nickname': '입주민',
          'vehicleNumber': editing ? '123가4567' : '',
          'role': 'user',
          'status': editing ? 'approved' : 'pending',
          'approved': editing,
          'profileComplete': editing,
        };
        final boot = auth.bootstrap();
        (await adapter.next()).reply(body: {
          'ok': true,
          'vehicleVerificationRequired': false,
          'session': session
        });
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
                                        ProfileSetupScreen(isEdit: editing))),
                            child: const Text('open')))))));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        (await adapter.next()).reply(body: {'ok': true, 'notices': []});
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await tester.pump();
        expect(find.byType(VehicleOcrInput), findsNothing);
        final plate = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == '차량번호');
        await tester.enterText(plate, '234나5678');
        await tester.pump();
        await tester.ensureVisible(find.text('승인 요청'));
        await tester.tap(find.text('승인 요청'));
        final save = await adapter.next();
        expect(save.options.path, '/api/profile');
        expect(save.options.data,
            {'nickname': '입주민', 'vehicleNumber': '234나5678'});
        if (policyChanged) {
          save.reply(status: 400, body: {
            'ok': false,
            'error': 'Photo verification is now required'
          });
          (await adapter.next()).reply(body: {
            'ok': true,
            'vehicleVerificationRequired': true,
            'session': session
          });
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pumpAndSettle();
          expect(find.byType(VehicleOcrInput), findsOneWidget);
          expect(
              tester
                  .widget<VehicleOcrInput>(find.byType(VehicleOcrInput))
                  .initialNumber,
              '234나5678');
          expect(auth.stage, AuthStage.needsProfileSetup);
          await tester.pumpWidget(const SizedBox.shrink());
          return;
        }
        save.reply(body: {
          'ok': true,
          'profile': {
            ...session,
            'status': 'pending',
            'approved': false,
            'vehicleNumber': '234나5678',
            'profileComplete': true
          }
        });
        (await adapter.next()).reply(body: {
          'ok': true,
          'vehicleVerificationRequired': false,
          'session': {
            ...session,
            'status': 'pending',
            'approved': false,
            'vehicleNumber': '234나5678',
            'profileComplete': true
          }
        });
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        expect(auth.stage, AuthStage.pending);
        await tester.pumpWidget(const SizedBox.shrink());
      });
      expect(tester.takeException(), isNull);
    });
  }
}
