import 'dart:io';

import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
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

  test('초기 상태는 회원 모드 (isGuestMode=false)', () {
    final p = AppStateProvider(services);
    expect(p.isGuestMode, false);
    p.dispose();
  });

  test('startGuest() → isGuestMode=true', () async {
    final p = AppStateProvider(services);
    await p.startGuest();
    expect(p.isGuestMode, true);
    p.stop();
    p.dispose();
  });

  test('게스트 진입 후 start() (회원 로그인) → isGuestMode=false (Critical 회귀 방지)', () async {
    final p = AppStateProvider(services);
    await p.startGuest();
    expect(p.isGuestMode, true);
    await p.start();
    expect(p.isGuestMode, false);
    p.stop();
    p.dispose();
  });

  test('reset() → isGuestMode=false', () async {
    final p = AppStateProvider(services);
    await p.startGuest();
    await p.reset();
    expect(p.isGuestMode, false);
    p.dispose();
  });
}
