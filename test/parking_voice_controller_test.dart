import 'dart:async';

import 'package:apt_ev_charging/core/errors.dart';
import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/models/session.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/services/parking_voice_api.dart';
import 'package:apt_ev_charging/services/parking_voice_controller.dart';
import 'package:apt_ev_charging/services/parking_voice_peer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const voiceParking = SlotDetail(
    callAllowed: true,
    parkingRegistrationId: 'parking-1',
    startTime: '2030-01-01T00:00:00Z',
    ownerEmail: 'owner@example.invalid');

class VoiceTestAuth extends ChangeNotifier implements AuthProvider {
  bool signedIn = true;
  @override
  AuthStage get stage => signedIn ? AuthStage.approved : AuthStage.anonymous;
  @override
  SessionInfo? get session => signedIn
      ? SessionInfo(
          email: 'member@example.invalid',
          name: '회원',
          nickname: '회원',
          picture: '',
          role: 'user',
          status: AuthStatus.approved,
          approved: true,
          authType: 'google',
          vehicleNumber: '123가4567',
          profileComplete: true)
      : null;
  void signOut() {
    signedIn = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class VoiceTestApi implements ParkingVoiceApi {
  bool enabled = true;
  bool failHeartbeat = false;
  int capabilityCalls = 0;
  Completer<Map<String, dynamic>>? delayedCreate;
  Completer<Map<String, dynamic>>? delayedAccept;
  final actions = <String>[];
  final sent = <String>[];
  Map<String, dynamic> call = {
    'id': 'call-1',
    'status': 'ringing',
    'direction': 'outgoing',
    'isCaller': true,
    'peerNickname': '차주',
    'slotId': 'fast50-1',
    'ringExpiresAt': '2099-01-01T00:00:00Z'
  };
  List<Map<String, dynamic>> signals = [];
  List<Map<String, dynamic>> incoming = [];
  @override
  Future<Map<String, dynamic>> fetchCapability() async {
    capabilityCalls++;
    return {
      'enabled': enabled,
      'reason': enabled ? null : 'TURN_NOT_CONFIGURED'
    };
  }

  @override
  Future<Map<String, dynamic>> create(String slotId, SlotDetail detail) =>
      delayedCreate?.future ?? Future.value({...call});
  @override
  Future<List<Map<String, dynamic>>> inbox() async => incoming;
  @override
  Future<Map<String, dynamic>> poll(String id, int afterSequence) async => {
        'call': {...call},
        'signals': signals
      };
  @override
  Future<Map<String, dynamic>> action(String id, String action) async {
    actions.add(action);
    if (action == 'heartbeat' && failHeartbeat) {
      throw NetworkException('offline');
    }
    if (action == 'accept' && delayedAccept != null) {
      return delayedAccept!.future;
    }
    if (action == 'accept') call = {...call, 'status': 'accepted'};
    return {...call};
  }

  @override
  Future<Map<String, dynamic>> ice(String id) async => {
        'iceServers': [
          {
            'urls': ['turns:relay.example.invalid:443'],
            'username': 'short-lived',
            'credential': 'test-only'
          }
        ],
        'expiresAt': '2099-01-01T00:00:00Z',
        'leaseExpiresAt': '2099-01-01T00:00:00Z'
      };
  @override
  Future<void> signal(
      String id, String type, Map<String, dynamic> payload) async {
    sent.add(type);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class VoiceTestPeer implements VoicePeer {
  int opens = 0;
  int closes = 0;
  bool muted = false;
  int offers = 0;
  final received = <String>[];
  Completer<void>? opening;
  @override
  Future<void> open(Map<String, dynamic> configuration,
      {required VoiceSignalCallback onSignal,
      required void Function(bool) onConnection,
      required VoidCallback onFailure}) async {
    opens++;
    if (opening != null) await opening!.future;
  }

  @override
  Future<void> offer() async {
    offers++;
  }

  @override
  Future<void> receive(String type, Map<String, dynamic> payload) async {
    received.add(payload['candidate']?.toString() ?? type);
  }

  @override
  void mute(bool value) {
    muted = value;
  }

  @override
  Future<void> speaker(bool value) async {}
  @override
  void close() {
    muted = true;
    closes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('idle background and logout do not announce a finished call',
      (tester) async {
    final api = VoiceTestApi()..enabled = false;
    final auth = VoiceTestAuth();
    final controller = ParkingVoiceController(api, auth);
    await tester.pump();
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(controller.message, isNull);
    auth.signOut();
    expect(controller.message, isNull);
    controller.dispose();
    auth.dispose();
  });

  testWidgets('backward wall clock cannot extend media after heartbeat loss',
      (tester) async {
    var now = DateTime.utc(2030);
    final api = VoiceTestApi();
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    final controller = ParkingVoiceController(api, auth,
        peerFactory: () => peer, now: () => now);
    await tester.pump();
    await controller.startCall('fast50-1', voiceParking);
    api.call = {...api.call, 'status': 'accepted'};
    await controller.refresh();
    api.failHeartbeat = true;
    now = now.subtract(const Duration(hours: 1));
    await tester.pump(const Duration(seconds: 16));
    expect(controller.activeCall, isNull);
    expect(peer.closes, greaterThan(0));
    expect(peer.muted, true);
    controller.dispose();
    auth.dispose();
  });

  testWidgets('ringing caller heartbeats without capturing audio',
      (tester) async {
    final api = VoiceTestApi();
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    final controller =
        ParkingVoiceController(api, auth, peerFactory: () => peer);
    await tester.pump();
    await controller.startCall('fast50-1', voiceParking);
    await tester.pump(const Duration(seconds: 5));
    expect(api.actions, contains('heartbeat'));
    expect(peer.opens, 0);
    expect(controller.activeCall?['status'], 'ringing');
    controller.dispose();
    auth.dispose();
  });

  testWidgets(
      'disabled capability retries after 60 seconds without inbox loops',
      (tester) async {
    var now = DateTime.utc(2030);
    final api = VoiceTestApi()..enabled = false;
    final auth = VoiceTestAuth();
    final controller = ParkingVoiceController(api, auth, now: () => now);
    await tester.pump();
    for (var iteration = 0; iteration < 5; iteration++) {
      await controller.refresh();
    }
    expect(api.capabilityCalls, 1);
    api.enabled = true;
    now = now.add(const Duration(seconds: 61));
    await controller.refresh();
    expect(api.capabilityCalls, 2);
    expect(controller.available, true);
    controller.dispose();
    auth.dispose();
  });

  testWidgets('late create after logout is cancelled without resurrecting call',
      (tester) async {
    final api = VoiceTestApi()
      ..delayedCreate = Completer<Map<String, dynamic>>();
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    final controller =
        ParkingVoiceController(api, auth, peerFactory: () => peer);
    await tester.pump();
    final creating = controller.startCall('fast50-1', voiceParking);
    await tester.pump();
    auth.signOut();
    api.delayedCreate!.complete({...api.call});
    await creating;
    expect(controller.activeCall, isNull);
    expect(peer.opens, 0);
    expect(api.actions, contains('cancel'));
    controller.dispose();
    auth.dispose();
  });

  testWidgets('callee waits for accepted server response before microphone',
      (tester) async {
    final api = VoiceTestApi()
      ..delayedAccept = Completer<Map<String, dynamic>>();
    api.call = {...api.call, 'isCaller': false, 'direction': 'incoming'};
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    final controller =
        ParkingVoiceController(api, auth, peerFactory: () => peer);
    await tester.pump();
    final accepting = controller.accept(api.call);
    await tester.pump();
    expect(peer.opens, 0);
    api.delayedAccept!.complete({...api.call, 'status': 'accepted'});
    await accepting;
    expect(peer.opens, 1);
    expect(peer.offers, 0);
    controller.dispose();
    auth.dispose();
  });

  testWidgets('remote signals are ordered and duplicate cursors are ignored',
      (tester) async {
    final api = VoiceTestApi();
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    final controller =
        ParkingVoiceController(api, auth, peerFactory: () => peer);
    await tester.pump();
    await controller.startCall('fast50-1', voiceParking);
    api.call = {...api.call, 'status': 'accepted'};
    api.signals = [
      {
        'sequence': 3,
        'type': 'ice',
        'payload': {'candidate': 'last'}
      },
      {
        'sequence': 1,
        'type': 'answer',
        'payload': {'sdp': 'fixture'}
      },
      {
        'sequence': 2,
        'type': 'ice',
        'payload': {'candidate': 'first'}
      },
    ];
    await controller.refresh();
    await controller.refresh();
    expect(peer.received, ['answer', 'first', 'last']);
    controller.dispose();
    auth.dispose();
  });

  testWidgets('TURN unavailable never captures microphone or creates calls',
      (tester) async {
    final api = VoiceTestApi()..enabled = false;
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    final controller =
        ParkingVoiceController(api, auth, peerFactory: () => peer);
    await tester.pump();
    await controller.startCall('fast50-1', voiceParking);
    expect(controller.available, false);
    expect(controller.activeCall, isNull);
    expect(peer.opens, 0);
    controller.dispose();
    auth.dispose();
  });

  testWidgets(
      'ringing never opens microphone; accepted caller creates one offer',
      (tester) async {
    final api = VoiceTestApi();
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    final controller =
        ParkingVoiceController(api, auth, peerFactory: () => peer);
    await tester.pump();
    await controller.startCall('fast50-1', voiceParking);
    expect(peer.opens, 0);
    api.call = {...api.call, 'status': 'accepted'};
    await controller.refresh();
    await controller.refresh();
    expect(peer.opens, 1);
    expect(peer.offers, 1);
    controller.dispose();
    auth.dispose();
  });

  testWidgets('logout closes and mutes synchronously even while peer opens',
      (tester) async {
    final api = VoiceTestApi();
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer()..opening = Completer<void>();
    final controller =
        ParkingVoiceController(api, auth, peerFactory: () => peer);
    await tester.pump();
    await controller.startCall('fast50-1', voiceParking);
    api.call = {...api.call, 'status': 'accepted'};
    final opening = controller.refresh();
    await tester.pump();
    auth.signOut();
    expect(peer.muted, true);
    expect(peer.closes, greaterThan(0));
    expect(controller.activeCall, isNull);
    peer.opening!.complete();
    await opening;
    expect(peer.offers, 0);
    controller.dispose();
    auth.dispose();
  });

  testWidgets('expired local lease stops media without waiting for a poll',
      (tester) async {
    var now = DateTime.utc(2030);
    final api = VoiceTestApi();
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    final controller = ParkingVoiceController(api, auth,
        peerFactory: () => peer, now: () => now);
    await tester.pump();
    await controller.startCall('fast50-1', voiceParking);
    api.call = {...api.call, 'status': 'accepted'};
    await controller.refresh();
    now = now.add(const Duration(seconds: 16));
    await tester.pump(const Duration(seconds: 1));
    expect(peer.muted, true);
    expect(controller.activeCall, isNull);
    controller.dispose();
    auth.dispose();
  });

  testWidgets(
      'background stops media synchronously and stale signals stay stopped',
      (tester) async {
    final api = VoiceTestApi();
    final auth = VoiceTestAuth();
    final peer = VoiceTestPeer();
    final controller =
        ParkingVoiceController(api, auth, peerFactory: () => peer);
    await tester.pump();
    await controller.startCall('fast50-1', voiceParking);
    api.call = {...api.call, 'status': 'accepted'};
    await controller.refresh();
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(peer.muted, true);
    expect(controller.activeCall, isNull);
    await controller.refresh();
    expect(peer.opens, 1);
    controller.dispose();
    auth.dispose();
  });
}
