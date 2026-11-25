import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/models/user.dart';
import 'package:apt_ev_charging/services/users_api.dart';
import 'package:apt_ev_charging/services/profile_api.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/screens/admin/console_member_usage.dart';
import 'package:apt_ev_charging/screens/admin/member_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('missing required data is incomplete independently of photo approval',
      () {
    final complete = AppUser.fromJson({
      'nickname': 'Resident',
      'vehicleNumber': '12가1234',
      'phoneNumber': '01012345678',
      'profileComplete': false,
      'lastUsedAt': '2026-09-01T00:00:00Z',
      'activeParking': true,
    });
    expect(complete.hasIncompleteProfile, isFalse);
    expect(complete.lastUsedAt, DateTime.utc(2026, 9));
    expect(complete.activeParking, isTrue);
    expect(AppUser.fromJson({'nickname': '   '}).hasIncompleteProfile, isTrue);
  });

  test('management query and mutations follow batch API contract', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final client = await ApiClient.init();
    await client.clearSession();
    final adapter = ControlledApi();
    client.dio.httpClientAdapter = adapter;
    addTearDown(adapter.close);
    final users = UsersApi(client);
    final listing = users.listMembers(
        incompleteOnly: true,
        inactiveValue: 2,
        inactiveUnit: 'months',
        limit: 50,
        offset: 50);
    final query = await adapter.next();
    expect(query.options.path, '/api/admin-members');
    expect(query.options.queryParameters, {
      'incompleteOnly': true,
      'inactiveValue': 2,
      'inactiveUnit': 'months',
      'limit': 50,
      'offset': 50
    });
    query.reply(body: {
      'ok': true,
      'users': [
        {'email': 'a@test.invalid'}
      ]
    });
    expect((await listing).single.email, 'a@test.invalid');
    final deletion = users.deleteMembers(['a@test.invalid']);
    final request = await adapter.next();
    expect(request.options.method, 'DELETE');
    expect(request.options.data, {
      'emails': ['a@test.invalid']
    });
    request.reply(body: {'ok': true, 'deletedCount': 1});
    expect(await deletion, 1);
    final clearing = users.clearPersonalData(['a@test.invalid']);
    final clearRequest = await adapter.next();
    expect(clearRequest.options.method, 'POST');
    expect(clearRequest.options.data, {
      'action': 'clear-personal-data',
      'emails': ['a@test.invalid'],
    });
    clearRequest.reply(body: {'ok': true, 'clearedCount': 1});
    expect(await clearing, 1);
    final profileSave = ProfileApi(client).updateProfile(
      nickname: '입주민 별명',
      vehicleNumber: '123가4567',
      vehiclePhotoBase64: 'data:image/png;base64,AA==',
      ocrCandidates: ['123가4567'],
    );
    final profileRequest = await adapter.next();
    expect(profileRequest.options.data, {
      'nickname': '입주민 별명',
      'vehicleNumber': '123가4567',
      'vehiclePhoto': 'data:image/png;base64,AA==',
      'ocrCandidates': ['123가4567'],
    });
    profileRequest.reply(body: {
      'ok': true,
      'profile': {'vehicleNumber': '123가4567'}
    });
    expect((await profileSave).vehicleNumber, '123가4567');
    final sending =
        users.requestProfiles(emails: ['b@test.invalid'], message: '추가 안내');
    final notice = await adapter.next();
    expect(notice.options.data, {
      'action': 'request-profile',
      'emails': ['b@test.invalid'],
      'message': '추가 안내'
    });
    notice.reply(body: {
      'ok': true,
      'sentCount': 1,
      'pushSentCount': 0,
      'pushFailedCount': 1
    });
    final result = await sending;
    expect(result.sentCount, 1);
    expect(result.pushSentCount, 0);
    expect(result.pushFailedCount, 1);
    expect(() => users.listMembers(inactiveValue: 0), throwsArgumentError);
    expect(() => users.deleteMembers([]), throwsArgumentError);
  });

  testWidgets('page selection protects admins and reviews deletion recipients',
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
      await tester.pumpWidget(MultiProvider(providers: [
        Provider.value(value: services),
        ChangeNotifierProvider.value(value: auth),
      ], child: const MaterialApp(home: ConsoleMemberUsage())));
      final query = await adapter.next();
      expect(query.options.path, '/api/admin-members');
      query.reply(body: {
        'ok': true,
        'users': [
          {'email': 'resident@test.invalid'},
          {
            'email': 'admin@test.invalid',
            'role': 'admin',
            'status': 'approved'
          },
        ]
      });
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('select-page')));
      await tester.pump();
      expect(find.text('1명 선택'), findsOneWidget);
      await tester.tap(find.text('선택 삭제'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Google 계정은 유지'), findsOneWidget);
      expect(find.textContaining('재가입'), findsOneWidget);
      expect(find.text('resident@test.invalid'), findsNWidgets(2));
      expect(find.text('admin@test.invalid'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('프로필 미완료만'));
      await tester.pump();
      final filtered = await adapter.next();
      expect(filtered.options.queryParameters['incompleteOnly'], true);
      filtered.reply(body: {'ok': true, 'users': []});
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('0명 선택'), findsOneWidget);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'filters must scroll above keyboard');
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'new filters ignore stale responses and leaving ignores late errors',
      (tester) async {
    await tester.runAsync(() async {
      final adapter = await mountManagement(tester);
      final initial = await adapter.next();
      await tester.tap(find.text('프로필 미완료만'));
      await tester.pump();
      final latest = await adapter.next();
      latest.reply(body: {
        'ok': true,
        'users': [
          {'email': 'latest@test.invalid'}
        ]
      });
      await drain(tester);
      initial.reply(body: {
        'ok': true,
        'users': [
          {'email': 'stale@test.invalid'}
        ]
      });
      await drain(tester);
      expect(find.text('latest@test.invalid'), findsOneWidget);
      expect(find.text('stale@test.invalid'), findsNothing);
      await tester.tap(find.text('프로필 미완료만'));
      final pending = await adapter.next();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.reply(status: 403, body: {'ok': false, 'error': 'Denied'});
      await drain(tester);
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'profile requests require incomplete recipients and review custom message',
      (tester) async {
    await tester.runAsync(() async {
      final adapter = await mountManagement(tester);
      (await adapter.next()).reply(body: {
        'ok': true,
        'users': [
          {
            'email': 'complete@test.invalid',
            'nickname': 'Resident',
            'vehicleNumber': '12가1234',
            'phoneNumber': '01012345678'
          },
          {'email': 'missing@test.invalid'},
        ]
      });
      await drain(tester);
      await tester.tap(find.byKey(const ValueKey('select-page')));
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, '정보 입력 요청'))
              .onPressed,
          isNull);
      final completeCard = find.ancestor(
          of: find.text('complete@test.invalid'),
          matching: find.byType(ListTile));
      await tester.tap(
          find.descendant(of: completeCard, matching: find.byType(Checkbox)));
      await tester.pump();
      await tester.tap(find.text('정보 입력 요청'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          '이번 주까지 입력해 주세요.');
      await tester.tap(find.text('발송 내용 확인'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('$profileRequestBaseMessage\n\n이번 주까지 입력해 주세요.'),
          findsOneWidget);
      await tester.tap(find.text('발송'));
      final sending = await adapter.next();
      expect(sending.options.data, {
        'action': 'request-profile',
        'emails': ['missing@test.invalid'],
        'message': '이번 주까지 입력해 주세요.'
      });
      sending.reply(body: {
        'ok': true,
        'sentCount': 1,
        'pushSentCount': 0,
        'pushFailedCount': 1
      });
      (await adapter.next()).reply(body: {'ok': true, 'users': []});
      await drain(tester);
      expect(find.text('앱 내 안내 1명 저장 · 푸시 0건 접수 / 1건 실패'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'server pages clear selection and inactivity uses calendar months',
      (tester) async {
    await tester.runAsync(() async {
      final adapter = await mountManagement(tester);
      (await adapter.next()).reply(body: {
        'ok': true,
        'users': List.generate(50, (i) => {'email': 'member$i@test.invalid'})
      });
      await drain(tester);
      await tester.tap(find.byKey(const ValueKey('select-page')));
      await tester.pump();
      expect(find.text('50명 선택'), findsOneWidget);
      await tester.tap(find.text('다음'));
      final page = await adapter.next();
      expect(page.options.queryParameters['offset'], 50);
      page.reply(body: {'ok': true, 'users': []});
      await drain(tester);
      expect(find.text('0명 선택'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '2');
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('개월').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(Checkbox).first);
      final inactive = await adapter.next();
      expect(inactive.options.queryParameters['inactiveValue'], 2);
      expect(inactive.options.queryParameters['inactiveUnit'], 'months');
      expect(inactive.options.queryParameters['offset'], 0);
      inactive.reply(body: {'ok': true, 'users': []});
      await drain(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets('invalid inactivity filter clears old actionable selections',
      (tester) async {
    await tester.runAsync(() async {
      final adapter = await mountManagement(tester);
      (await adapter.next()).reply(body: {
        'ok': true,
        'users': [
          {'email': 'resident@test.invalid'}
        ]
      });
      await drain(tester);
      await tester.tap(find.byKey(const ValueKey('select-page')));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('0명 선택'), findsOneWidget);
      expect(find.text('미사용 기간은 1 이상의 정수로 입력해 주세요.'), findsOneWidget);
      expect(
          tester
              .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, '선택 삭제'))
              .onPressed,
          isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
}

Future<ControlledApi> mountManagement(WidgetTester tester) async {
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
  await tester.pumpWidget(MultiProvider(providers: [
    Provider.value(value: services),
    ChangeNotifierProvider.value(value: auth)
  ], child: const MaterialApp(home: ConsoleMemberUsage())));
  return adapter;
}

Future<void> drain(WidgetTester tester) async {
  await Future<void>.delayed(const Duration(milliseconds: 150));
  await tester.pump();
}
