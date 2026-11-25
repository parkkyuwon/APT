import 'package:apt_ev_charging/screens/public/parking_voice_screen.dart';
import 'package:apt_ev_charging/services/parking_voice_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'parking_voice_controller_test.dart'
    show VoiceTestApi, VoiceTestAuth, VoiceTestPeer;

void main() {
  testWidgets('hidden panel reserves no height with status bar padding',
      (tester) async {
    final api = VoiceTestApi()..enabled = false;
    final auth = VoiceTestAuth();
    final controller = ParkingVoiceController(api, auth);
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
        home: Align(
            alignment: Alignment.topCenter,
            child: MediaQuery(
                data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
                child: ParkingVoicePanel(controller: controller)))));
    expect(tester.getSize(find.byType(ParkingVoicePanel)).height, 0);
    expect(find.byType(SafeArea), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });

  testWidgets('visible panel respects status bar padding', (tester) async {
    final api = VoiceTestApi()..enabled = false;
    final auth = VoiceTestAuth();
    final controller = ParkingVoiceController(api, auth);
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
        home: Align(
            alignment: Alignment.topCenter,
            child: MediaQuery(
                data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
                child: ParkingVoicePanel(
                    controller: controller, showAvailability: true)))));
    final top = tester.getTopLeft(find.byType(Card)).dy;
    final hasSafeArea = find.byType(SafeArea).evaluate().length == 1;
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
    expect(top, greaterThanOrEqualTo(24));
    expect(hasSafeArea, true);
  });

  testWidgets('optional panel is absent without a voice controller',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ParkingVoicePanel())));
    expect(find.text('앱 음성통화'), findsNothing);
  });

  testWidgets(
      'incoming call needs explicit acceptance and explains microphone use',
      (tester) async {
    final api = VoiceTestApi();
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    api.call = {...api.call, 'direction': 'incoming', 'isCaller': false};
    api.incoming = [
      {...api.call}
    ];
    final controller =
        ParkingVoiceController(api, auth, peerFactory: () => peer);
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ParkingVoicePanel(controller: controller))));
    await tester.pump();
    expect(find.text('수락'), findsOneWidget);
    expect(find.textContaining('수락하기 전에는 마이크'), findsOneWidget);
    expect(peer.opens, 0);
    await tester.tap(find.text('수락'));
    await tester.pump();
    expect(api.actions, contains('accept'));
    expect(peer.opens, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    auth.dispose();
  });
}
