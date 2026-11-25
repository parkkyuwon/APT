import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/models/departure_request.dart';
import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/services/departure_requests_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('received request retains requesting vehicle and read status', () {
    final request = DepartureRequest.fromJson({
      'id': 17,
      'slotId': 'fast50-1',
      'slotName': 'B1 급속 1번',
      'requesterVehicleNumber': '123가4567',
      'createdAt': '2026-10-10T12:00:00Z',
      'readAt': null,
      'pushStatus': 'failed',
    });
    expect(request.id, 17);
    expect(request.requesterVehicleNumber, '123가4567');
    expect(request.isRead, false);
    expect(request.pushStatus, 'failed');
  });

  test('send uses current parking identity without choosing sender vehicle',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final client = await ApiClient.init();
    await client.clearSession();
    final adapter = ControlledApi();
    client.dio.httpClientAdapter = adapter;
    addTearDown(adapter.close);
    final service = DepartureRequestsApi(client);
    final pending = service.send(
        slotId: 'fast50-1',
        detail: const SlotDetail(
          ownerEmail: 'owner@example.invalid',
          startTime: '2026-10-10T10:00:00Z',
        ));
    final request = await adapter.next();
    expect(request.options.path, '/api/departure-requests');
    expect(request.options.data, {
      'slotId': 'fast50-1',
      'expectedOwnerEmail': 'owner@example.invalid',
      'expectedStartTime': '2026-10-10T10:00:00Z',
    });
    request.reply(body: {
      'ok': true,
      'request': {
        'id': 17,
        'slotId': 'fast50-1',
        'requesterVehicleNumber': '123가4567',
        'pushStatus': 'skipped',
      }
    });
    expect((await pending).id, 17);
    final listing = service.list(beforeId: 17);
    final listRequest = await adapter.next();
    expect(listRequest.options.queryParameters['before'], 17);
    listRequest.reply(body: {'ok': true, 'requests': []});
    expect(await listing, isEmpty);
    final marking = service.markRead(17);
    final markRequest = await adapter.next();
    expect(markRequest.options.method, 'PATCH');
    expect(markRequest.options.data, {'id': '17'});
    markRequest.reply(body: {
      'ok': true,
      'request': {
        'id': 17,
        'readAt': '2026-10-10T13:00:00Z',
      }
    });
    expect((await marking).isRead, true);
  });
}
