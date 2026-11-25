import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/screens/public/departure_requests_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

void main() {
  for (final leave in [false, true]) {
    testWidgets('inbox shows requesting vehicle; late response ignored=$leave',
        (tester) async {
      await tester.runAsync(() async {
        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({});
        await AppConfig.init();
        final api = await ApiClient.init();
        await api.clearSession();
        final adapter = ControlledApi();
        api.dio.httpClientAdapter = adapter;
        addTearDown(adapter.close);
        await tester.pumpWidget(Provider.value(
            value: ApiServices.from(api),
            child: const MaterialApp(home: DepartureRequestsScreen())));
        final request = await adapter.next();
        if (leave) await tester.pumpWidget(const SizedBox.shrink());
        request.reply(body: {
          'ok': true,
          'requests': [
            {
              'id': 4,
              'slotId': 'fast50-1',
              'slotName': 'B1 급속 1번',
              'requesterVehicleNumber': '123가4567',
              'createdAt': '2026-10-10T10:00:00Z',
            }
          ]
        });
        // Secure cookie processing finishes after the adapter reply.
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          if (leave || find.textContaining('123가4567').evaluate().isNotEmpty) {
            break;
          }
        }
        if (!leave) {
          expect(find.textContaining('123가4567'), findsOneWidget);
          expect(find.textContaining('B1 급속 1번'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
      expect(tester.takeException(), isNull);
    });
  }
}
