import 'dart:async';
import 'package:apt_ev_charging/services/push_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logout clears local alerts even if remote token deletion fails',
      () async {
    final calls = <String>[];
    final reset = await resetPushRegistration(clearNotifications: () async {
      calls.add('clear');
    }, disableAutoInit: () async {
      calls.add('disable');
    }, deleteToken: () async {
      calls.add('delete');
      throw StateError('offline');
    });
    expect(calls, ['clear', 'disable', 'delete']);
    expect(reset, false);
  });
  test('APNs readiness waits and stops after account invalidation', () async {
    var attempts = 0;
    final token = await waitForApnsToken(
        read: () async => ++attempts == 2 ? 'apns' : null,
        isCurrent: () => true,
        delay: () async {});
    expect(token, 'apns');
    var current = true;
    final cancelled = await waitForApnsToken(
        read: () async {
          current = false;
          return null;
        },
        isCurrent: () => current,
        delay: () async {});
    expect(cancelled, isNull);
  });
  test('account changes invalidate delayed token retrieval before registration',
      () async {
    final token = Completer<String?>();
    final registered = <String>[];
    final identity = PushIdentity();
    final binding = identity.bind('first',
        obtainToken: () => token.future,
        register: (value) async => registered.add(value));
    identity.setAccount(null);
    token.complete('private-token');
    await binding;
    expect(registered, isEmpty);
    expect(identity.registered, false);
  });
  test('late registration does not mark the next account as registered',
      () async {
    final registration = Completer<void>();
    final identity = PushIdentity();
    final binding = identity.bind('first',
        obtainToken: () async => 'token', register: (_) => registration.future);
    await Future<void>.delayed(Duration.zero);
    identity.setAccount('second');
    registration.complete();
    await binding;
    expect(identity.registered, false);
  });
  test('only valid departure ids can open request details', () {
    expect(departureRequestId({'type': 'departure_request', 'requestId': '17'}),
        17);
    expect(departureRequestId({'type': 'chat', 'requestId': '17'}), isNull);
    expect(departureRequestId({'type': 'departure_request', 'requestId': '-1'}),
        isNull);
    expect(departureRequestId({'type': 'departure_request', 'requestId': 'x'}),
        isNull);
  });
}
