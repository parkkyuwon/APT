import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/app_route_observer.dart';
import 'package:apt_ev_charging/core/deep_link.dart';
import 'package:apt_ev_charging/local_test/local_api_adapter.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/screens/public/home_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const nfc = MethodChannel('apt_ev/foreground_nfc');

  testWidgets('one NFC contact parks once; a new contact checks out the owner',
      (tester) async {
    await tester.runAsync(() async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({});
        await AppConfig.init();
        final client = await ApiClient.init();
        await client.clearSession();
        final originalBase = client.dio.options.baseUrl;
        client.dio.options.baseUrl = LocalApiAdapter.baseUrl;
        client.dio.httpClientAdapter = LocalApiAdapter();
        binding.defaultBinaryMessenger
            .setMockMethodCallHandler(nfc, (_) async => true);
        final services = ApiServices.from(client);
        final auth = AuthProvider(services);
        final app = AppStateProvider(services, auth: auth);
        addTearDown(() {
          DeepLink.stop();
          DeepLink.consumePendingSlot();
          app.dispose();
          auth.dispose();
          client.dio.options.baseUrl = originalBase;
          binding.defaultBinaryMessenger.setMockMethodCallHandler(nfc, null);
          debugDefaultTargetPlatformOverride = null;
        });
        await auth.bootstrap();
        DeepLink.start();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: app),
          ],
          child: MaterialApp(
              navigatorObservers: [appRouteObserver], home: const HomeScreen()),
        ));

        Future<void> settle() async {
          for (var i = 0; i < 20; i++) {
            await Future<void>.delayed(Duration.zero);
            await tester.pump();
          }
        }

        Future<void> scan(int sequence) async {
          await binding.defaultBinaryMessenger.handlePlatformMessage(
            nfc.name,
            const StandardMethodCodec().encodeMethodCall(MethodCall('tag', {
              'scanId': sequence,
              'uri':
                  'https://apt-ev-charging.vercel.app/index.html?slot=fast50-1',
            })),
            (_) {},
          );
          await settle();
        }

        await settle();
        await scan(1);
        expect(app.state.slotDetails['fast50-1']?.ownerEmail,
            LocalApiAdapter.memberEmail);
        expect(app.state.slotDetails['fast50-1']?.callAllowed, isFalse);
        await scan(1);
        expect(app.state.slotDetails['fast50-1']?.ownerEmail,
            LocalApiAdapter.memberEmail);
        await scan(2);
        expect(app.state.slotDetails['fast50-1'], isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
