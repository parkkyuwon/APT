import 'package:apt_ev_charging/models/app_state.dart';
import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/models/session.dart';
import 'package:apt_ev_charging/widgets/slot_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detail = SlotDetail(
    ownerEmail: 'member@example.invalid',
    ownerInstanceAt: '2026-10-14T00:00:00Z',
    ownerNickname: 'Old name',
    vehicleNumber: '123가4567',
    contact: '010-1234-5678',
    startTime: '2026-10-14T10:00:00',
    chargeDuration: '1시간',
  );
  Future<void> open(WidgetTester tester, SessionInfo session,
      {SlotDetail current = detail,
      ValueChanged<SlotDialogResult?>? result}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
          onPressed: () async {
            final value = await showSlotDialog(context,
                slot: const ParkingSlot(id: 'fast50-1', typeId: 'fast50'),
                currentDetail: current,
                appState: AppState.empty(),
                session: session);
            result?.call(value);
          },
          child: const Text('open')),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  SessionInfo session(String email, {String role = 'user'}) =>
      SessionInfo.fromJson({
        'email': email,
        'name': 'New Google name',
        'vehicleNumber': '123가4567',
        'role': role,
        'approved': true
      });

  testWidgets('direct parking works with no phone data or contact input',
      (tester) async {
    SlotDialogResult? saved;
    await open(tester, session('member@example.invalid'),
        current: const SlotDetail(), result: (value) => saved = value);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.scrollUntilVisible(find.text('주차하기'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('주차하기'));
    await tester.pumpAndSettle();
    expect(saved?.action, SlotDialogAction.park);
    expect(saved?.detail?.contact, '');
    expect(saved?.detail?.contactVisible, isFalse);
  });

  testWidgets('renamed owner can edit by email', (tester) async {
    await open(tester, session(' MEMBER@example.invalid '));
    expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled, true);
    expect(tester.widget<TextField>(find.byType(TextField).first).readOnly,
        isTrue);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(detail.contact), findsNothing);
  });
  testWidgets('Google display name change keeps the same parking identity',
      (tester) async {
    SlotDialogResult? saved;
    await open(tester, session(detail.ownerEmail),
        result: (value) => saved = value);
    await tester.scrollUntilVisible(find.text('수정하기'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(saved?.detail?.ownerEmail, detail.ownerEmail);
    expect(saved?.detail?.ownerInstanceAt, detail.ownerInstanceAt);
    expect(saved?.detail?.ownerNickname, 'New Google name');
  });
  testWidgets('legacy public contact is no longer displayed', (tester) async {
    await open(tester, session('other@example.invalid'),
        current: detail.copyWith(contactVisible: true));
    expect(find.text('010-****-5678'), findsNothing);
    expect(find.text(detail.contact), findsNothing);
  });
  for (final blocked in [false, true]) {
    testWidgets('admin can release and toggle blocked=$blocked registration',
        (tester) async {
      SlotDialogResult? saved;
      final admin = session('admin@example.invalid', role: 'admin');
      await open(tester, admin,
          current: detail.copyWith(parkingBlocked: blocked),
          result: (value) => saved = value);
      await tester.scrollUntilVisible(find.text('출차하기'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('출차하기'));
      await tester.pumpAndSettle();
      expect(saved?.action, SlotDialogAction.checkout);
      await open(tester, admin,
          current: detail.copyWith(parkingBlocked: blocked),
          result: (value) => saved = value);
      final button = find.text(blocked ? '주차 가능으로 표시' : '주차 불가로 표시');
      await tester.scrollUntilVisible(button, 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(saved?.action, SlotDialogAction.toggleBlocked);
    });
  }
  testWidgets('private contact never enters another members field',
      (tester) async {
    await open(tester, session('other@example.invalid'));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(detail.contact), findsNothing);
  });
  testWidgets('admin edits another vehicle without taking ownership',
      (tester) async {
    SlotDialogResult? saved;
    await open(tester, session('admin@example.invalid', role: 'admin'),
        result: (value) => saved = value);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled, true);
    expect(tester.widget<TextField>(find.byType(TextField).first).readOnly,
        isFalse);
    await tester.scrollUntilVisible(find.text('수정하기'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(saved?.detail?.ownerEmail, detail.ownerEmail);
    expect(saved?.detail?.ownerNickname, detail.ownerNickname);
  });
  testWidgets('blocked registered vehicle stays read only for other members',
      (tester) async {
    await open(tester, session('other@example.invalid'),
        current: detail.copyWith(parkingBlocked: true));
    expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled, false);
    expect(find.byType(TextField), findsOneWidget);
  });
}
