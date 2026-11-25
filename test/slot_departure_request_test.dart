import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/models/session.dart';
import 'package:apt_ev_charging/widgets/departure_request_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/core/errors.dart';

SessionInfo member(String email,
        {String vehicle = '123가4567', bool approved = true}) =>
    SessionInfo.fromJson(
        {'email': email, 'vehicleNumber': vehicle, 'approved': approved});

void main() {
  const detail = SlotDetail(
      ownerEmail: 'other@example.invalid',
      vehicleNumber: '999가8888',
      startTime: '2026-10-10T10:00:00Z',
      departureTime: '2099-10-10T10:00:00Z');
  test('request allowed before estimated departure but not self or guest', () {
    expect(canRequestDeparture(member('me@example.invalid'), detail), true);
    expect(
        canRequestDeparture(
            member('me@example.invalid'), detail.copyWith(ownerEmail: '')),
        true);
    expect(canRequestDeparture(member('other@example.invalid'), detail), false);
    expect(canRequestDeparture(null, detail), false);
    expect(
        canRequestDeparture(
            member('me@example.invalid', approved: false), detail),
        false);
    expect(
        canRequestDeparture(member('me@example.invalid', vehicle: ''), detail),
        false);
    expect(
        canRequestDeparture(member('me@example.invalid'), const SlotDetail()),
        false);
    expect(
        canRequestDeparture(member('me@example.invalid'),
            detail.copyWith(parkingBlocked: true)),
        false);
  });
  testWidgets('confirmation shows requesting vehicle and cancel sends nothing',
      (tester) async {
    var sent = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DepartureRequestButton(
                session: member('me@example.invalid'),
                detail: detail,
                slotId: 'fast50-1',
                onSend: () async {
                  sent++;
                  return const DepartureRequestFeedback('접수됨');
                }))));
    await tester.tap(find.text('출차 요청하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('123가4567'), findsOneWidget);
    expect(find.textContaining('직접 확인'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(sent, 0);
  });
  testWidgets('rate limited request displays next retry and disables repeat',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DepartureRequestButton(
                session: member('me@example.invalid'),
                detail: detail,
                slotId: 'fast50-1',
                onSend: () async => throw ApiException(
                    statusCode: 429,
                    message: 'Cooldown',
                    rawBody: {'retryAfterSeconds': 15})))));
    await tester.tap(find.text('출차 요청하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인 후 요청'));
    await tester.pumpAndSettle();
    expect(find.textContaining('다음 요청 가능'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.pump(const Duration(seconds: 16));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
