import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/core/indoor_location_bridge.dart';
import 'package:apt_ev_charging/models/home_area.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('apt_ev/indoor_location');
  const bridge = IndoorLocationBridge();
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  test('configure sends agreed native account and revision contract', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return {'monitoring': true};
    });
    await bridge.configure(HomeArea(
        accountScope: 'a',
        latitude: 37,
        longitude: 127,
        revision: 3,
        enabled: true));
    expect(received!.method, 'configure');
    expect(received!.arguments, containsPair('accountScope', 'a'));
    expect(received!.arguments, containsPair('revision', 3));
    expect(received!.arguments, containsPair('siteId', 'home'));
  });
  test('settings target uses the native channel without granting permissions',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    for (final target in [
      'locationServices',
      'location',
      'background',
      'notifications'
    ]) {
      expect(await bridge.openSettings(target), isTrue);
      expect(calls.last.method, 'openSettings');
      expect(calls.last.arguments, {'target': target});
    }
    expect(calls, hasLength(4));
    await expectLater(bridge.openSettings('unknown'), throwsArgumentError);
    expect(calls, hasLength(4));
  });
  test('settings disable includes owner so old screen cannot stop new account',
      () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });
    await bridge.disableForAccount('previous-account');
    expect(received!.method, 'disable');
    expect(received!.arguments, {'accountScope': 'previous-account'});
  });
  test('unsupported hosts report unavailable and do not invent entries',
      () async {
    expect((await bridge.status()).supported, isFalse);
    expect(await bridge.consumeEntry(), isNull);
    await bridge.disable();
  });
  test('malformed current fix is unavailable rather than crashing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => {'latitude': 37});
    expect(await bridge.currentLocation(), isNull);
  });
}
