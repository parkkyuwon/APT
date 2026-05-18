import 'dart:io';

import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [HttpOverrides] that refuses all connections — keeps the test hermetic by
/// making every Dio call fail with [SocketException] immediately.
class _NoNetworkOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('No network in tests');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ApiServices services;

  setUpAll(() async {
    HttpOverrides.global = _NoNetworkOverrides();
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    final api = await ApiClient.init();
    services = ApiServices.from(api);
  });

  test('enterGuestMode → stage=guest', () {
    final a = AuthProvider(services);
    a.enterGuestMode();
    expect(a.stage, AuthStage.guest);
    a.dispose();
  });

  test('guest 상태에서 exitGuestMode → stage=anonymous', () {
    final a = AuthProvider(services);
    a.enterGuestMode();
    a.exitGuestMode();
    expect(a.stage, AuthStage.anonymous);
    a.dispose();
  });

  test('guest 아닐 때 exitGuestMode 는 무효 (가드)', () {
    final a = AuthProvider(services);
    final before = a.stage;
    a.exitGuestMode();
    expect(a.stage, before);
    a.dispose();
  });
}
