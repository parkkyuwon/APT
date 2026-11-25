import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apt_ev_charging/models/indoor_positioning.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/providers/indoor_dataset_provider.dart';
import 'package:apt_ev_charging/providers/indoor_position_provider.dart';
import 'package:apt_ev_charging/screens/admin/indoor_survey_history_screen.dart';
import 'package:apt_ev_charging/services/indoor_access_controller.dart';
import 'package:apt_ev_charging/services/indoor_survey_store.dart';

class _Admin extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAdmin => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Access extends ChangeNotifier implements IndoorAccessController {
  @override
  IndoorDatasetProvider? get publication => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends IndoorSurveyStore {
  @override
  Future<List<SurveySession>> load(String scope, {String? siteId}) async => [
        for (final floor in ['B1', 'B2'])
          SurveySession(
              id: floor,
              accountScope: scope,
              floor: floor,
              label: '기둥 1',
              xPct: 50,
              yPct: 50,
              startedAt: DateTime(2026),
              endedAt: DateTime(2026),
              observations: [
                BeaconObservation(
                    beaconId: 'same-beacon',
                    rssi: -60,
                    observedAt: DateTime(2026))
              ])
      ];
}

void main() {
  testWidgets('history floor filter keeps B1 and B2 measurements separate',
      (tester) async {
    final controller =
        IndoorPositionProvider(accountScope: 'admin', store: _Store());
    await controller.load();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _Admin()),
          ChangeNotifierProvider<IndoorAccessController>.value(
              value: _Access()),
        ],
        child: MaterialApp(
            home: IndoorSurveyHistoryScreen(controller: controller))));
    expect(find.text('B1 · 기둥 1'), findsOneWidget);
    expect(find.text('B2 · 기둥 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'B1'));
    await tester.pump();
    expect(find.text('B1 · 기둥 1'), findsOneWidget);
    expect(find.text('B2 · 기둥 1'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'B2'));
    await tester.pump();
    expect(find.text('B1 · 기둥 1'), findsNothing);
    expect(find.text('B2 · 기둥 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
