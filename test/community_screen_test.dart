import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/screens/public/board_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/controlled_api.dart';

void main() {
  testWidgets('mutation during an older list request queues fresh data',
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
      await tester.pumpWidget(Provider.value(
          value: ApiServices.from(client),
          child: const MaterialApp(home: BoardScreen())));
      final oldList = await adapter.next();
      await tester.tap(find.text('글쓰기'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextFormField).first, '새 글');
      await tester.enterText(find.byType(TextFormField).last, '새 내용');
      await tester.ensureVisible(find.text('저장'));
      await tester.tap(find.text('저장'));
      final save = await adapter.next();
      save.reply(body: {
        'ok': true,
        'post': {'id': 2, 'title': '새 글', 'content': '새 내용'}
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      oldList.reply(body: {'ok': true, 'posts': []});
      for (var attempt = 0;
          attempt < 100 && adapter.pending.length < 3;
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      expect(adapter.pending.length, 3,
          reason: 'Saving must queue a fresh list after the old GET');
      final refresh = await adapter.next();
      refresh.reply(body: {
        'ok': true,
        'posts': [
          {'id': 2, 'title': '새 글'}
        ]
      });
      for (var attempt = 0;
          attempt < 100 && find.text('새 글').evaluate().isEmpty;
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      expect(find.text('새 글'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
  for (final leave in [false, true]) {
    testWidgets('failed post preserves input; leaving=$leave is safe',
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
        await tester.pumpWidget(Provider.value(
          value: ApiServices.from(client),
          child: const MaterialApp(home: PostEditor()),
        ));
        await tester.enterText(find.byType(TextFormField).first, '주차장 의견');
        await tester.enterText(find.byType(TextFormField).last, '입력 내용 보존');
        await tester.ensureVisible(find.text('저장'));
        await tester.tap(find.text('저장'));
        await tester.pump();
        final request = await adapter.next();
        expect(
            request.options.data, {'title': '주차장 의견', 'content': '입력 내용 보존'});
        if (leave) await tester.pumpWidget(const SizedBox.shrink());
        request.reply(status: 503, body: {'ok': false, 'error': '저장 실패'});
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await tester.pump();
        if (!leave) {
          expect(find.text('주차장 의견'), findsOneWidget);
          expect(find.text('입력 내용 보존'), findsOneWidget);
          expect(find.text('저장 실패'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
      expect(tester.takeException(), isNull);
    });
  }
}
