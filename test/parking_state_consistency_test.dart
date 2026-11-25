import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/errors.dart';
import 'package:apt_ev_charging/core/state_cache.dart';
import 'package:apt_ev_charging/models/app_state.dart';
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
  late ControlledApi api;
  late ApiServices services;
  late AuthProvider auth;
  late AppStateProvider app;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final client = await ApiClient.init();
    await client.clearSession();
    api = ControlledApi();
    client.dio.httpClientAdapter = api;
    services = ApiServices.from(client);
    auth = AuthProvider(services);
    final boot = auth.bootstrap();
    (await api.next()).reply(body: {
      'ok': true,
      'session': {
        'email': 'owner@example.test',
        'status': 'approved',
        'approved': true,
        'profileComplete': true
      }
    });
    await boot;
    app = AppStateProvider(services, auth: auth);
  });
  tearDown(() {
    app.dispose();
    auth.dispose();
    api.close();
  });

  test('old GET cannot replace a successful mutation or its cache', () async {
    final readFuture = app.refresh();
    final read = await api.next();
    final writeFuture = app.upsertSlotDetail(
        slotId: 'fast50-1',
        detail: const SlotDetail(vehicleNumber: '123가4567'));
    final write = await api.next();
    write.reply(body: {
      'ok': true,
      'state': {
        'stateVersion': 5,
        'slotDetails': {
          'fast50-1': {'vehicleNumber': '123가4567'}
        }
      }
    });
    await writeFuture;
    read.reply(body: {
      'ok': true,
      'state': {'stateVersion': 4}
    });
    await readFuture;
    expect(app.state.slotDetails['fast50-1']?.vehicleNumber, '123가4567');
    await StateCache.save(app.state, owner: auth.session!.email);
    expect(
        StateCache.load(owner: auth.session!.email)?.slotDetails, isNotEmpty);
  });

  test('queued writes use the authoritative preceding state and version',
      () async {
    final first = app.upsertSlotDetail(
        slotId: 'fast50-1',
        detail: const SlotDetail(vehicleNumber: '123가4567'));
    final request = await api.next();
    final second = app.upsertSlotDetail(
        slotId: 'fast50-2',
        detail: const SlotDetail(vehicleNumber: '456나7890'));
    await Future<void>.delayed(Duration.zero);
    expect(api.pending.where((r) => r.options.method == 'POST').length, 1);
    request.reply(body: {
      'ok': true,
      'state': {
        'stateVersion': 7,
        'slotDetails': {
          'fast50-1': {'vehicleNumber': '123가4567'}
        }
      }
    });
    await first;
    final next = await api.next();
    expect((next.options.data as Map)['stateVersion'], 7);
    expect(((next.options.data as Map)['slotDetails'] as Map).keys,
        containsAll(['fast50-1', 'fast50-2']));
    next.reply(body: {
      'ok': true,
      'state': {'stateVersion': 8}
    });
    await second;
    expect(app.state.toJson()['stateVersion'], 8);
  });

  for (final item in [
    (401, null, AuthStage.anonymous),
    (403, 'blocked', AuthStage.blocked),
    (403, null, AuthStage.approved)
  ]) {
    test(
        'state error ${item.$1}/${item.$2} applies only authoritative auth restrictions',
        () async {
      final read = app.refresh();
      (await api.next()).reply(status: item.$1, body: {
        'ok': false,
        'error': 'Denied',
        if (item.$2 != null) 'authStatus': item.$2
      });
      await read;
      expect(auth.stage, item.$3);
      if (item.$3 != AuthStage.approved) expect(app.state.slotDetails, isEmpty);
    });
  }
  for (final invalid in [null, [], 'bad']) {
    test('state API rejects missing or invalid state $invalid', () async {
      final fetch = services.state.fetch();
      final failed = expectLater(fetch, throwsA(isA<ApiException>()));
      (await api.next())
          .reply(body: {'ok': true, if (invalid != null) 'state': invalid});
      await failed;
    });
  }
  test('failed first write cannot erase queued successful second write',
      () async {
    final first = app.upsertSlotDetail(
        slotId: 'fast50-1',
        detail: const SlotDetail(vehicleNumber: '123가4567'));
    final firstError = expectLater(first, throwsA(isA<ApiException>()));
    final request = await api.next();
    final second = app.upsertSlotDetail(
        slotId: 'fast50-2',
        detail: const SlotDetail(vehicleNumber: '456나7890'));
    request.reply(status: 409, body: {'ok': false, 'error': 'Conflict'});
    await firstError;
    final next = await api.next();
    expect(
        ((next.options.data as Map)['slotDetails'] as Map)
            .containsKey('fast50-1'),
        false);
    next.reply(body: {
      'ok': true,
      'state': {
        'stateVersion': 2,
        'slotDetails': {
          'fast50-2': {'vehicleNumber': '456나7890'}
        }
      }
    });
    await second;
    expect(app.state.slotDetails.keys, ['fast50-2']);
  });

  test('blocked bootstrap error overrides an approved cached session',
      () async {
    final boot = auth.bootstrap();
    (await api.next()).reply(
        status: 403,
        body: {'ok': false, 'error': 'Blocked', 'authStatus': 'blocked'});
    await boot;
    expect(auth.stage, AuthStage.blocked);
    expect(auth.isBusy, false);
  });

  test('malformed state refresh preserves prior authoritative state', () async {
    final first = app.refresh();
    (await api.next()).reply(body: {
      'ok': true,
      'state': {'stateVersion': 4, 'maintenanceMode': true}
    });
    await first;
    final second = app.refresh();
    (await api.next()).reply(body: {'ok': true});
    await second;
    expect(app.state.maintenanceMode, true);
    expect(app.errorMessage, isNotNull);
  });

  test('state version round trips and legacy cache starts at zero', () {
    expect(
        AppState.fromJson({'stateVersion': 12}).toJson()['stateVersion'], 12);
    expect(AppState.fromJson({}).toJson()['stateVersion'], 0);
  });

  test('full snapshot keeps its captured version while queued', () async {
    final load = app.refresh();
    (await api.next()).reply(body: {
      'ok': true,
      'state': {'stateVersion': 6}
    });
    await load;
    final first = app.upsertSlotDetail(
        slotId: 'fast50-1',
        detail: const SlotDetail(vehicleNumber: '123가4567'));
    final request = await api.next();
    final full = app.saveFullState({'maintenanceMode': true});
    final conflict = expectLater(full, throwsA(isA<ApiException>()));
    request.reply(body: {
      'ok': true,
      'state': {'stateVersion': 7}
    });
    await first;
    final next = await api.next();
    expect((next.options.data as Map)['stateVersion'], 6);
    next.reply(status: 409, body: {'ok': false, 'error': 'Reload required'});
    await conflict;
    expect(app.state.stateVersion, 7);
  });

  for (final status in [403, 503]) {
    test('legacy photo restriction routes to verification for HTTP $status',
        () async {
      final read = app.refresh();
      (await api.next()).reply(status: status, body: {
        'ok': false,
        'error': 'Vehicle photo required',
        'authStatus': 'needsPhotoVerification',
      });
      await read;
      expect(auth.stage, AuthStage.needsPhotoVerification);
    });
  }

  const parked = SlotDetail(
    ownerEmail: 'owner@example.test',
    vehicleNumber: '123가4567',
    parkingRegistrationId: 'registration',
    startTime: '2026-10-21T00:00:00Z',
  );

  Future<void> loadParking() async {
    final read = app.refresh();
    (await api.next()).reply(body: {
      'ok': true,
      'state': {
        'stateVersion': 4,
        'slotDetails': {'fast50-1': parked.toJson()}
      }
    });
    await read;
  }

  test('voice preference refreshes the whole state before the next admin CAS',
      () async {
    await loadParking();
    final setting = app.setParkingCallAllowed('fast50-1', true);
    (await api.next()).reply(body: {
      'ok': true,
      'detail': parked.copyWith(callAllowed: true).toJson(),
    });
    final refresh = await api.next();
    expect(refresh.options.path, '/api/state');
    refresh.reply(body: {
      'ok': true,
      'state': {
        'stateVersion': 6,
        'slotDetails': {
          'fast50-1': parked.copyWith(callAllowed: true).toJson(),
          'fast50-2': {
            'vehicleNumber': '456나7890',
            'ownerEmail': 'peer@example.test'
          }
        }
      }
    });
    await setting;
    final save = app.saveFullState(app.state.toJson());
    final request = await api.next();
    expect((request.options.data as Map)['stateVersion'], 6);
    expect(
        ((request.options.data as Map)['slotDetails'] as Map)
            .containsKey('fast50-2'),
        true);
    request.reply(body: {
      'ok': true,
      'state': {'stateVersion': 7}
    });
    await save;
  });

  test(
      'failed post-preference refresh preserves acknowledged flag and old version with warning',
      () async {
    await loadParking();
    final setting = app.setParkingCallAllowed('fast50-1', true);
    final failed = expectLater(setting, throwsA(isA<StateError>()));
    (await api.next()).reply(body: {
      'ok': true,
      'detail': parked.copyWith(callAllowed: true).toJson(),
    });
    (await api.next())
        .reply(status: 503, body: {'ok': false, 'error': 'Unavailable'});
    await failed;
    expect(app.state.slotDetails['fast50-1']?.callAllowed, true);
    expect(app.state.stateVersion, 4);
    expect(auth.stage, AuthStage.approved);
  });
}
