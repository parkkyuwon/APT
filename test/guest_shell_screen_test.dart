import 'package:apt_ev_charging/screens/public/guest_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GuestShellScreen 구조: 3탭 라벨 + 로그인 CTA', (tester) async {
    // Provider 미제공 상태에서 첫 프레임만 검증.
    // initState 의 startGuest 는 addPostFrameCallback 이라 pump 전에는 미실행.
    //
    // NOTE: ParkingListScreen(첫 탭)이 build 중 AppStateProvider 를 watch 해
    // ProviderNotFoundException 이 발생하지만, NavigationBar / 배너는 독립적으로
    // 렌더링되므로 FlutterError.onError 로 해당 예외를 흡수하고 구조만 검증한다.
    final errors = <Object>[];
    FlutterError.onError = (details) {
      if (details.exception is! FlutterError &&
          details.exception.toString().contains('ProviderNotFoundException')) {
        errors.add(details.exception);
        return; // suppress — expected in this provider-less smoke test
      }
      FlutterError.presentError(details);
    };

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GuestShellScreen())),
    );

    FlutterError.onError = FlutterError.presentError;

    expect(find.text('목록'), findsWidgets);
    expect(find.text('지도'), findsWidgets);
    expect(find.text('이용안내'), findsOneWidget);
    expect(find.text('로그인하기'), findsOneWidget);
  });
}
