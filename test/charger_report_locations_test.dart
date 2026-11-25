import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/screens/public/charger_reports_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

Future<void> pumpUntilVisible(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(finder, findsOneWidget);
}

void main() {
  testWidgets(
      'direct admin entry waits for authoritative locations and preserves draft on fetch failure',
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
      // Deliberately no HomeScreen or AppStateProvider: admin can enter directly.
      await tester.pumpWidget(Provider.value(
          value: ApiServices.from(client),
          child: const MaterialApp(
              home: ChargerReportEditor(initialSlotId: 'custom-9'))));
      await tester.enterText(find.byType(TextFormField), '기존 입력 보존');
      final delayed = await adapter.next();
      expect(delayed.options.path, '/api/state');
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      expect(find.textContaining('fast50-1'), findsNothing);
      delayed.reply(status: 403, body: {'ok': false, 'error': '위치 조회 실패'});
      await pumpUntilVisible(tester, find.text('위치 조회 실패'));
      expect(find.text('기존 입력 보존'), findsOneWidget);
      expect(find.text('위치 조회 실패'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      await tester.tap(find.text('위치 다시 불러오기'));
      final retry = await adapter.next();
      retry.reply(body: {
        'ok': true,
        'state': {
          'slots': {
            'fast50': [
              {'id': 'custom-9', 'typeId': 'fast50'}
            ]
          },
          'slotNames': {'custom-9': '실제 충전기'},
        }
      });
      await pumpUntilVisible(tester, find.textContaining('실제 충전기'));
      expect(find.textContaining('실제 충전기'), findsOneWidget);
      expect(find.text('기존 입력 보존'), findsOneWidget);
      await tester.ensureVisible(find.text('신고 접수'));
      await tester.tap(find.text('신고 접수'));
      final submit = await adapter.next();
      expect(submit.options.path, '/api/charger-reports');
      expect(submit.options.data,
          {'slotId': 'custom-9', 'description': '기존 입력 보존'});
      submit.reply(status: 503, body: {'ok': false, 'error': '접수 실패'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('기존 입력 보존'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
}
