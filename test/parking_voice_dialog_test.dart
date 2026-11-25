import 'package:apt_ev_charging/models/app_state.dart';
import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/models/session.dart';
import 'package:apt_ev_charging/widgets/slot_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SessionInfo session(String email, {bool admin = false}) =>
      SessionInfo.fromJson({
        'email': email,
        'vehicleNumber': '123가4567',
        'name': 'Owner',
        'approved': true,
        'role': admin ? 'admin' : 'user',
      });
  Future<void> open(WidgetTester tester,
      {required SessionInfo user,
      SlotDetail current = const SlotDetail(),
      bool? available,
      ValueChanged<SlotDialogResult?>? result,
      Future<void> Function()? call}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      final value = await showSlotDialog(context,
                          slot: const ParkingSlot(
                              id: 'fast50-1', typeId: 'fast50'),
                          currentDetail: current,
                          appState: AppState.empty(),
                          session: user,
                          voiceAvailable: available,
                          onVoiceCall: call);
                      result?.call(value);
                    },
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  const parked = SlotDetail(
      vehicleNumber: '123가4567',
      ownerEmail: 'owner@example.invalid',
      parkingRegistrationId: 'opaque-current',
      startTime: '2026-10-21T00:00:00Z',
      callAllowed: true);
  testWidgets(
      'new parking defaults off and stays disabled without TURN capability',
      (tester) async {
    await open(tester, user: session('owner@example.invalid'));
    final checkbox =
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).first);
    expect(checkbox.title, isA<Text>());
    expect(checkbox.value, isFalse);
    expect(checkbox.onChanged, isNull);
    expect(find.textContaining('중계 서버'), findsOneWidget);
  });
  testWidgets('admin editing another parking cannot opt in on owners behalf',
      (tester) async {
    await open(tester,
        user: session('admin@example.invalid', admin: true),
        current: parked,
        available: true);
    expect(find.text('이번 주차 중 앱 음성통화 받기'), findsNothing);
  });
  testWidgets(
      'new owner opt-in is returned separately from generic parking fields',
      (tester) async {
    SlotDialogResult? result;
    await open(tester,
        user: session('owner@example.invalid'),
        available: true,
        result: (value) => result = value);
    final checkbox = find.text('이번 주차 중 앱 음성통화 받기');
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
    await tester.ensureVisible(find.text('주차하기'));
    await tester.tap(find.text('주차하기'));
    await tester.pumpAndSettle();
    expect(result?.callAllowed, isTrue);
    expect(result?.detail?.callAllowed, isFalse);
    expect(result?.detail?.parkingRegistrationId, '');
  });
  testWidgets(
      'unchanged owner preference is not resubmitted with ordinary parking edits',
      (tester) async {
    SlotDialogResult? result;
    await open(tester,
        user: session('owner@example.invalid'),
        available: true,
        current: parked.copyWith(chargeDuration: '1시간'),
        result: (value) => result = value);
    await tester.ensureVisible(find.text('수정하기'));
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(result?.callAllowed, isNull);
    expect(result?.detail?.callAllowed, isTrue);
  });
  testWidgets('owner can revoke existing opt-in even when TURN is unavailable',
      (tester) async {
    SlotDialogResult? result;
    await open(tester,
        user: session('owner@example.invalid'),
        available: false,
        current: parked.copyWith(chargeDuration: '1시간'),
        result: (value) => result = value);
    await tester.ensureVisible(find.text('이번 주차 중 앱 음성통화 받기'));
    await tester.tap(find.text('이번 주차 중 앱 음성통화 받기'));
    await tester.pump();
    await tester.ensureVisible(find.text('수정하기'));
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(result?.callAllowed, isFalse);
    expect(result?.detail?.callAllowed, isTrue);
  });
  testWidgets(
      'call appears only for another current opted-in parking with capability',
      (tester) async {
    var calls = 0;
    await open(tester,
        user: session('other@example.invalid'),
        current: parked,
        available: true, call: () async {
      calls++;
    });
    await tester.ensureVisible(find.text('차주에게 앱 통화'));
    await tester.tap(find.text('차주에게 앱 통화'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await open(tester,
        user: session('other@example.invalid'),
        current: parked.copyWith(callAllowed: false),
        available: true);
    expect(find.text('차주에게 앱 통화'), findsNothing);
  });
}
