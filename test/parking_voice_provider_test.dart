import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('failed voice opt-in leaves successful parking registered and off',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final client = await ApiClient.init();
    await client.clearSession();
    final transport = ControlledApi();
    client.dio.httpClientAdapter = transport;
    addTearDown(transport.close);
    final services = ApiServices.from(client);
    final auth = AuthProvider(services);
    addTearDown(auth.dispose);
    final boot = auth.bootstrap();
    (await transport.next()).reply(body: {
      'ok': true,
      'session': {
        'email': 'owner@example.invalid',
        'nickname': 'Owner',
        'status': 'approved',
        'approved': true,
        'profileComplete': true,
      }
    });
    await boot;
    final app = AppStateProvider(services, auth: auth);
    addTearDown(app.dispose);
    const detail = SlotDetail(
        vehicleNumber: '123가4567',
        ownerEmail: 'owner@example.invalid',
        startTime: '2026-10-21T00:00:00Z');
    final registration = app.upsertSlotDetail(
        slotId: 'fast50-1', detail: detail, callAllowed: true);
    final failed = expectLater(registration, throwsA(isA<StateError>()));
    final saved = await transport.next();
    expect(saved.options.path, '/api/state');
    saved.reply(body: {
      'ok': true,
      'state': {
        'slotDetails': {
          'fast50-1': {
            ...detail.toJson(),
            'parkingRegistrationId': 'server-opaque',
            'callAllowed': false
          }
        }
      }
    });
    final optIn = await transport.next();
    expect(optIn.options.path, '/api/parking-voice');
    expect(optIn.options.data, {
      'action': 'set-availability',
      'slotId': 'fast50-1',
      'expectedParkingRegistrationId': 'server-opaque',
      'expectedStartTime': detail.startTime,
      'callAllowed': true
    });
    expect(app.state.slotDetails['fast50-1']?.callAllowed, isFalse);
    optIn.reply(status: 403, body: {'ok': false, 'error': 'Opt-in denied'});
    await failed;
    expect(app.state.slotDetails['fast50-1']?.parkingRegistrationId,
        'server-opaque');
    expect(app.state.slotDetails['fast50-1']?.callAllowed, isFalse);
  });
}
