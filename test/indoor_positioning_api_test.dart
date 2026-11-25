import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/errors.dart';
import 'package:apt_ev_charging/services/indoor_positioning_api.dart';
import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late IndoorPositioningApi api;
  late ControlledApi adapter;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final client = await ApiClient.init();
    await client.clearSession();
    adapter = ControlledApi();
    client.dio.httpClientAdapter = adapter;
    api = IndoorPositioningApi(client);
  });
  tearDown(() => adapter.close());
  test('fetch downloads authoritative revision and enabled state', () async {
    final pending = api.fetch();
    final request = await adapter.next();
    expect(request.options.path, '/api/indoor-positioning');
    request.reply(body: {
      'ok': true,
      'dataset': {
        'schemaVersion': 1,
        'revision': 3,
        'enabled': false,
        'siteId': 'home',
        'mapVersion': 'simplified-v1',
        'surveys': [],
        'beaconPositions': {}
      }
    });
    final result = await pending;
    expect(result.revision, 3);
    expect(result.enabled, isFalse);
  });
  test('publish conflict remains a failure and sends expectedRevision',
      () async {
    final pending =
        api.publish(expectedRevision: 3, enabled: true, surveys: const []);
    final expectation = expectLater(pending, throwsA(isA<ApiException>()));
    final request = await adapter.next();
    expect(request.options.method, 'PUT');
    expect(request.options.data['expectedRevision'], 3);
    request.reply(status: 409, body: {'ok': false, 'error': '다른 관리자가 변경했습니다.'});
    await expectation;
  });
}
