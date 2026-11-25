import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/errors.dart';
import 'package:apt_ev_charging/models/community.dart';
import 'package:apt_ev_charging/services/community_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CommunityApi api;
  late ControlledApi adapter;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final client = await ApiClient.init();
    await client.clearSession();
    adapter = ControlledApi();
    client.dio.httpClientAdapter = adapter;
    api = CommunityApi(client);
  });
  tearDown(() => adapter.close());

  test('board edits preserve post identity and accept server result', () async {
    final pending = api.savePost(title: ' 주차장 ', content: ' 의견 ', id: 12);
    final request = await adapter.next();
    expect(request.options.path, '/api/board');
    expect(request.options.method, 'PUT');
    expect(request.options.data, {'id': 12, 'title': '주차장', 'content': '의견'});
    request.reply(body: {
      'ok': true,
      'post': {'id': 12, 'title': '주차장', 'content': '의견', 'authorName': '회원'}
    });
    expect((await pending).authorName, '회원');
  });

  test('report creation sends location and optional photo without identity',
      () async {
    final pending = api.createReport(slotId: 'fast50-1', description: '충전 중단');
    final request = await adapter.next();
    expect(request.options.path, '/api/charger-reports');
    expect(
        request.options.data, {'slotId': 'fast50-1', 'description': '충전 중단'});
    request.reply(body: {
      'ok': true,
      'report': {'id': 7, 'slotId': 'fast50-1', 'status': 'received'}
    });
    expect((await pending).statusLabel, '접수');
  });

  test('denied delete remains a failure', () async {
    final pending = api.deletePost(12);
    final expected = expectLater(pending, throwsA(isA<ApiException>()));
    final request = await adapter.next();
    expect(request.options.queryParameters, {'id': 12});
    request.reply(status: 403, body: {'ok': false, 'error': '권한 없음'});
    await expected;
  });

  test('unknown report status never appears as resolved', () {
    final report = ChargerReport.fromJson({'id': 1, 'status': 'unexpected'});
    expect(report.statusLabel, '상태 확인 필요');
    expect(report.status, 'unexpected');
  });

  test('report list keeps photo marker; detail fetch requests a single report',
      () async {
    final listing = api.reports();
    final listRequest = await adapter.next();
    listRequest.reply(body: {
      'ok': true,
      'reports': [
        {'id': 8, 'hasPhoto': true}
      ]
    });
    final reports = await listing;
    expect(reports.single.hasPhoto, isTrue);
    expect(reports.single.photo, isEmpty);
    final detail = api.report(8);
    final detailRequest = await adapter.next();
    expect(detailRequest.options.queryParameters, {'id': 8});
    detailRequest.reply(body: {
      'ok': true,
      'report': {'id': 8, 'photo': 'data:image/png;base64,AA=='}
    });
    expect((await detail).photo, isNotEmpty);
  });
}
