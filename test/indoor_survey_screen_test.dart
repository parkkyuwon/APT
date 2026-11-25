import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/models/indoor_positioning.dart';
import 'package:apt_ev_charging/providers/indoor_position_provider.dart';
import 'package:apt_ev_charging/screens/admin/indoor_survey_screen.dart';
import 'package:apt_ev_charging/services/indoor_survey_store.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class _Admin extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAdmin => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends IndoorSurveyStore {
  @override
  Future<List<SurveySession>> load(String accountScope,
          {String? siteId}) async =>
      [];
}

void main() {
  testWidgets('requires measurement point and separates sensor installation',
      (tester) async {
    final controller =
        IndoorPositionProvider(accountScope: 'resident', store: _Store());
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: _Admin(),
        child: MaterialApp(
            home: IndoorSurveyScreen(
                accountScope: 'resident', controller: controller))));
    await tester.pumpAndSettle();
    expect(find.textContaining('측정 당시 내가 서 있는 위치'), findsOneWidget);
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '15초 측정 시작'));
    expect(button.onPressed, isNull);
    final rect = tester.getRect(find.byKey(const ValueKey('indoor-map-image')));
    await tester.tapAt(rect.center);
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, '15초 측정 시작'))
            .onPressed,
        isNotNull);
    expect(find.text('비콘 설치 좌표는 변경하지 않습니다.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
