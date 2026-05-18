import 'dart:io';

import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/providers/connectivity_provider.dart';
import 'package:apt_ev_charging/screens/public/guest_shell_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [HttpOverrides] that refuses all connections — keeps the widget test
/// hermetic by making every Dio call fail with [SocketException] immediately,
/// so [AppStateProvider.startGuest] / [refresh] never reaches the network.
class _NoNetworkOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('No network in tests');
  }
}

// Initialised once in setUpAll.
late ApiServices _sharedServices;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Prevent any real HTTP calls inside the test process.
    HttpOverrides.global = _NoNetworkOverrides();

    // Satisfy AppConfig.init() (SharedPreferences.getInstance) without a
    // platform channel — standard flutter_test technique.
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();

    // Build the real ApiClient / ApiServices.  SecureCookieJar only touches
    // flutter_secure_storage lazily (on actual cookie read/write), so no
    // platform channel is needed here.
    final api = await ApiClient.init();
    _sharedServices = ApiServices.from(api);
  });

  testWidgets('GuestShellScreen 구조: 3탭 라벨 + 로그인 CTA', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
              create: (_) => AuthProvider(_sharedServices)),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
          ChangeNotifierProvider(
            create: (ctx) => AppStateProvider(
              _sharedServices,
              connectivity: ctx.read<ConnectivityProvider>(),
            ),
          ),
          Provider.value(value: _sharedServices),
        ],
        child: const MaterialApp(home: GuestShellScreen()),
      ),
    );
    // Drain all pending Dio timers created by startGuest() -> refresh().
    // _NoNetworkOverrides makes every HTTP call fail instantly with
    // SocketException, so AppStateProvider catches a NetworkException and
    // stays at AppState.empty() — no real network traffic occurs.
    await tester.pumpAndSettle();

    expect(find.text('목록'), findsWidgets);
    expect(find.text('지도'), findsWidgets);
    expect(find.text('이용안내'), findsOneWidget);
    expect(find.text('로그인하기'), findsOneWidget);
  });
}
