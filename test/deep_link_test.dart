import 'package:apt_ev_charging/core/deep_link.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => DeepLink.consumePendingSlot());
  tearDown(() {
    DeepLink.stop();
    DeepLink.consumePendingSlot();
    binding.platformDispatcher.clearDefaultRouteNameTestValue();
  });

  test('captures cold launch slots before the home screen mounts', () {
    binding.platformDispatcher.defaultRouteNameTestValue =
        '/index.html?slot=slow7-1&mode=smart';
    DeepLink.start();
    expect(DeepLink.consumePendingSlot(), 'slow7-1');
  });

  test('accepts generated slot URLs and consumes once', () {
    expect(
        DeepLink.handleRoute(
          'https://apt-ev-charging.vercel.app/index.html?slot=fast50-1&mode=smart',
        ),
        isTrue);
    expect(DeepLink.consumePendingSlot(), 'fast50-1');
    expect(DeepLink.consumePendingSlot(), isNull);
  });

  test('does not enqueue invalid direct slot values', () {
    DeepLink.setPendingSlot('fast50/1');
    expect(DeepLink.consumePendingSlot(), isNull);
  });

  test('an old home completion cannot release a new home processing guard', () {
    final old = DeepLink.beginSlotHandling('fast50-1');
    final current = DeepLink.beginSlotHandling('fast50-2');
    DeepLink.finishSlotHandling(old);
    DeepLink.setPendingSlot('fast50-2');
    expect(DeepLink.hasPendingSlot, isFalse);
    DeepLink.finishSlotHandling(current);
    DeepLink.setPendingSlot('fast50-2');
    expect(DeepLink.consumePendingSlot(), 'fast50-2');
  });

  test('accepts platform path with percent decoding and fragment', () {
    expect(DeepLink.handleRoute('/index.html?slot=fast50%2D2#map'), isTrue);
    expect(DeepLink.consumePendingSlot(), 'fast50-2');
  });

  test('ignores unrelated and malformed routes', () {
    for (final route in [
      '/',
      '/other?slot=fast50-1',
      'https://example.com/index.html?slot=fast50-1',
      'http://apt-ev-charging.vercel.app/index.html?slot=fast50-1',
      '/index.html?slot=',
      '/index.html?slot=%00',
      '/index.html?slot=one&slot=two',
      '/index.html?slot=%zz',
      '/index.html?slot=fast50%2F1',
    ]) {
      expect(DeepLink.handleRoute(route), isFalse, reason: route);
      expect(DeepLink.consumePendingSlot(), isNull);
    }
  });

  test('notifies for live slots and keeps the latest pending link', () {
    var notifications = 0;
    void listener() => notifications++;
    DeepLink.addListener(listener);
    try {
      DeepLink.handleRoute('/index.html?slot=fast50-1');
      DeepLink.handleRoute('/index.html?slot=fast50-1');
      DeepLink.handleRoute('/index.html?slot=fast50-2');
      expect(notifications, 2);
      expect(DeepLink.consumePendingSlot(), 'fast50-2');
    } finally {
      DeepLink.removeListener(listener);
    }
  });

  testWidgets('handles pushRoute and pushRouteInformation while running',
      (_) async {
    DeepLink.start();
    DeepLink.start();
    Future<void> send(String method, dynamic arguments) async {
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
    }

    await send('pushRoute', '/index.html?slot=fast50-1');
    expect(DeepLink.consumePendingSlot(), 'fast50-1');
    await send('pushRouteInformation', {
      'location': '/index.html?slot=fast50-2',
      'state': null,
    });
    expect(DeepLink.consumePendingSlot(), 'fast50-2');
  });
}
