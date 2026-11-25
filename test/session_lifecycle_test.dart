import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/errors.dart';
import 'package:apt_ev_charging/core/state_cache.dart';
import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiClient client;
  late ApiServices services;
  late ControlledApi transport;
  late AppStateProvider provider;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    client = await ApiClient.init();
    await client.clearSession();
    transport = ControlledApi();
    client.dio.httpClientAdapter = transport;
    services = ApiServices.from(client);
    provider = AppStateProvider(services);
  });

  tearDown(() {
    provider.dispose();
    transport.close();
  });

  test('late member response cannot replace guest state or cache it', () async {
    final memberStart = provider.start();
    final member = await transport.next();
    expect(member.options.path, '/api/state');
    final guestStart = provider.startGuest();
    final publicRead = await transport.next();
    member.reply(body: {
      'ok': true,
      'state': {'maintenanceMode': true}
    });
    await memberStart;
    publicRead.reply();
    await guestStart;
    expect(provider.state.maintenanceMode, false);
    expect(transport.pending.map((r) => r.options.path),
        contains('/api/public-dashboard'));
    expect(StateCache.load(), isNull);
  });

  test('late read after reset cannot restore state or restart polling',
      () async {
    final start = provider.start();
    final read = await transport.next();
    await provider.reset();
    read.reply(body: {
      'ok': true,
      'state': {'maintenanceMode': true}
    });
    await start;
    expect(provider.state.maintenanceMode, false);
    expect(provider.lastUpdated, isNull);
    expect(StateCache.load(), isNull);
  });

  test('late successful save after reset cannot restore member data', () async {
    final save = provider.upsertSlotDetail(
      slotId: 'fast50-1',
      detail: const SlotDetail(ownerEmail: 'member@example.test'),
    );
    final write = await transport.next();
    await provider.reset();
    write.reply(body: {
      'ok': true,
      'state': {
        'slotDetails': {
          'fast50-1': {'ownerEmail': 'member@example.test'}
        }
      }
    });
    await save;
    expect(provider.state.slotDetails, isEmpty);
    expect(StateCache.load(), isNull);
  });

  test('late failed save cannot roll member snapshot back over guest data',
      () async {
    final start = provider.start();
    (await transport.next()).reply(body: {
      'ok': true,
      'state': {'maintenanceMode': true}
    });
    await start;
    final save = provider.upsertSlotDetail(
      slotId: 'fast50-1',
      detail: const SlotDetail(ownerEmail: 'member@example.test'),
    );
    final write = await transport.next();
    final failure = expectLater(save, throwsA(isA<ApiException>()));
    final guestStart = provider.startGuest();
    final publicRead = await transport.next();
    publicRead.reply();
    await guestStart;
    write.reply(status: 403, body: {'ok': false, 'error': 'Denied'});
    await failure;
    expect(provider.state.maintenanceMode, false);
    expect(provider.state.slotDetails, isEmpty);
  });

  for (final networkFailure in [false, true]) {
    test(
        'logout clears cookies and ETag after '
        '${networkFailure ? 'transport failure' : 'server refusal'}', () async {
      final uri = Uri.parse(AppConfig.apiBaseUrl);
      await client.cookieJar.saveFromResponse(uri, [Cookie('session', 'test')]);
      client.etagCache
          .store(key: '/api/state', etag: 'old', body: {'ok': true});
      final logout = services.auth.logout();
      final failure = expectLater(logout, throwsA(isA<Exception>()));
      final request = await transport.next();
      if (networkFailure) {
        request.fail();
      } else {
        request.reply(status: 403, body: {'ok': false, 'error': 'Denied'});
      }
      await failure;
      expect(await client.cookieJar.loadForRequest(uri), isEmpty);
      expect(client.etagCache.getEtag('/api/state'), isNull);
    });
  }

  test('authentication restoration cannot undo the user choosing guest mode',
      () async {
    final auth = AuthProvider(services);
    addTearDown(auth.dispose);
    final bootstrap = auth.bootstrap();
    final request = await transport.next();
    auth.enterGuestMode();
    request.reply(body: _memberSession());
    await bootstrap;
    expect(auth.stage, AuthStage.guest);
    expect(auth.session, isNull);
  });

  test('logout immediately clears member state and stops further member reads',
      () async {
    final auth = AuthProvider(services);
    addTearDown(auth.dispose);
    provider.dispose();
    provider = AppStateProvider(services, auth: auth);
    final bootstrap = auth.bootstrap();
    (await transport.next()).reply(body: _memberSession());
    await bootstrap;
    final start = provider.start();
    (await transport.next()).reply(body: {
      'ok': true,
      'state': {
        'slotDetails': {
          'fast50-1': {'ownerEmail': 'member@example.test'}
        }
      }
    });
    await start;
    expect(provider.state.slotDetails, isNotEmpty);
    final logout = auth.logout();
    final request = await transport.next();
    // Finish the in-process server response even if the assertion fails.
    request.reply();
    expect(auth.stage, AuthStage.anonymous);
    expect(provider.state.slotDetails, isEmpty);
    await logout;
    await provider.refresh();
    expect(transport.pending.where((r) => r.options.path == '/api/state'),
        hasLength(1));
    await StateCache.clear();
    expect(StateCache.load(), isNull);
  });

  test('late HTTP response cannot refill ETag after clearing session',
      () async {
    final read = services.state.fetch();
    final request = await transport.next();
    await client.clearSession();
    request.response.complete(ResponseBody.fromString(
      '{"ok":true,"state":{"maintenanceMode":true}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'etag': ['old-session-etag'],
        'set-cookie': ['session=old-session; Path=/']
      },
    ));
    // A stale response may be discarded or rejected, but cannot persist data.
    try {
      await read;
    } on Exception {
      // Session invalidation is allowed to reject the outdated response.
    }
    expect(client.etagCache.getEtag('/api/state'), isNull);
    expect(
        await client.cookieJar.loadForRequest(Uri.parse(AppConfig.apiBaseUrl)),
        isEmpty);
  });
}

Map<String, dynamic> _memberSession() => {
      'ok': true,
      'session': {
        'email': 'member@example.test',
        'role': 'user',
        'status': 'approved',
        'approved': true,
        'profileComplete': true,
      }
    };
