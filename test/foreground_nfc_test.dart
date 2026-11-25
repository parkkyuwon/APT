import 'package:apt_ev_charging/core/deep_link.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('apt_ev/foreground_nfc');
  final commands = <String>[];

  Future<void> scan(Object? arguments) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec()
          .encodeMethodCall(MethodCall('tag', arguments)),
      (_) {},
    );
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    commands.clear();
    DeepLink.consumePendingSlot();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      commands.add(call.method);
      return true;
    });
  });

  tearDown(() async {
    DeepLink.stop();
    await Future<void>.delayed(Duration.zero);
    DeepLink.consumePendingSlot();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('foreground NFC delivers a validated slot without a navigation intent',
      () async {
    DeepLink.start();
    await Future<void>.delayed(Duration.zero);
    await scan({
      'scanId': 1,
      'uri': 'https://apt-ev-charging.vercel.app/index.html?slot=fast50-1',
    });
    expect(DeepLink.consumePendingSlot(), 'fast50-1');
    expect(commands.where((command) => command == 'start'), hasLength(1));
  });

  test('duplicate delivery never toggles parking again after consumption',
      () async {
    DeepLink.start();
    await Future<void>.delayed(Duration.zero);
    final tag = {
      'scanId': 1,
      'uri': 'https://apt-ev-charging.vercel.app/index.html?slot=fast50-1',
    };
    await scan(tag);
    expect(DeepLink.consumePendingSlot(), 'fast50-1');
    await scan(tag);
    expect(DeepLink.consumePendingSlot(), isNull);
    await scan({...tag, 'scanId': 2});
    expect(DeepLink.consumePendingSlot(), 'fast50-1');
  });

  test('NFC rejects relative, foreign and ambiguous URLs', () async {
    DeepLink.start();
    await Future<void>.delayed(Duration.zero);
    var sequence = 0;
    for (final uri in [
      '/index.html?slot=fast50-1',
      'https://example.com/index.html?slot=fast50-1',
      'https://apt-ev-charging.vercel.app/index.html?slot=a&slot=b',
      'https://apt-ev-charging.vercel.app/other?slot=fast50-1',
    ]) {
      await scan({'scanId': ++sequence, 'uri': uri});
      expect(DeepLink.consumePendingSlot(), isNull, reason: uri);
    }
  });

  test('stop ignores already queued tags and is idempotent', () async {
    DeepLink.start();
    await Future<void>.delayed(Duration.zero);
    DeepLink.stop();
    DeepLink.stop();
    await Future<void>.delayed(Duration.zero);
    await scan({
      'scanId': 1,
      'uri': 'https://apt-ev-charging.vercel.app/index.html?slot=fast50-1',
    });
    expect(DeepLink.consumePendingSlot(), isNull);
    expect(commands.where((command) => command == 'stop'), hasLength(1));
  });
}
