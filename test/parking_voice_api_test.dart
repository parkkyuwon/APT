import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/errors.dart';
import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/services/parking_voice_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ParkingVoiceApi api;
  late ControlledApi adapter;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final client = await ApiClient.init();
    await client.clearSession();
    adapter = ControlledApi();
    client.dio.httpClientAdapter = adapter;
    api = ParkingVoiceApi(client);
  });
  tearDown(() => adapter.close());
  const detail = SlotDetail(startTime: '2026-10-21T00:00:00Z');

  test('capability uses authenticated shared transport', () async {
    final future = api.fetchCapability();
    final request = await adapter.next();
    expect(request.options.path, '/api/parking-voice');
    expect(request.options.queryParameters, {'action': 'capability'});
    request.reply(body: {'ok': true, 'enabled': false, 'reason': 'TURN 미설정'});
    expect((await future)['enabled'], false);
  });

  test('create addresses current parking without arbitrary callee', () async {
    final future = api.create('fast50-1', detail);
    final request = await adapter.next();
    final data = request.options.data as Map;
    expect(data['action'], 'create');
    expect(data['slotId'], 'fast50-1');
    expect(data['expectedStartTime'], detail.startTime);
    expect(data['requestKey'], isNotEmpty);
    expect(data.containsKey('calleeEmail'), false);
    request.reply(body: {'ok': true, 'call': {'id': 'c1', 'status': 'ringing'}});
    expect((await future)['id'], 'c1');
  });

  test('signal and poll retain sequence and message identity', () async {
    final sending = api.signal('c1', 'ice', {'candidate': 'candidate:test'});
    final request = await adapter.next();
    expect(request.options.data['clientMessageId'], isNotEmpty);
    expect(request.options.data['payload'], {'candidate': 'candidate:test'});
    request.reply(body: {'ok': true, 'call': {'id': 'c1'}});
    await sending;
    final polling = api.poll('c1', 8);
    final pollRequest = await adapter.next();
    expect(pollRequest.options.queryParameters,
        {'action': 'poll', 'id': 'c1', 'afterSequence': 8});
    pollRequest.reply(body: {'ok': true, 'call': {'id': 'c1'}, 'signals': []});
    expect((await polling)['signals'], isEmpty);
  });

  test('denied accept stays a failure', () async {
    final future = api.action('c1', 'accept');
    final failure = expectLater(future, throwsA(isA<ApiException>()));
    final request = await adapter.next();
    request.reply(status: 409, body: {'ok': false, 'error': '현재 주차가 아닙니다.'});
    await failure;
  });
}
