import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:apt_ev_charging/models/indoor_positioning.dart';
import 'package:apt_ev_charging/providers/indoor_position_provider.dart';
import 'package:apt_ev_charging/services/beacon_observer.dart';
import 'package:apt_ev_charging/services/indoor_survey_store.dart';

class MemorySurveyStore extends IndoorSurveyStore {
  final data = <SurveySession>[];
  @override
  Future<List<SurveySession>> load(String accountScope,
          {String? siteId}) async =>
      data.where((s) => s.accountScope == accountScope).toList();
  @override
  Future<void> save(SurveySession session) async => data.add(session);
  bool closed = false;
  @override
  Future<void> close() async {
    closed = true;
  }
}

class ReadyScanSource implements BeaconScanSource {
  @override
  Stream<List<BeaconObservation>> get packets => const Stream.empty();
  @override
  Stream<bool> get available => const Stream.empty();
  @override
  Future<void> prepare() async {}
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

class PendingSurveyStore extends MemorySurveyStore {
  final calls = <Completer<List<SurveySession>>>[];
  @override
  Future<List<SurveySession>> load(String scope, {String? siteId}) {
    final result = Completer<List<SurveySession>>();
    calls.add(result);
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('repeated measurements keep separate sessions and scope', () async {
    final store = MemorySurveyStore();
    final controller =
        IndoorPositionProvider(accountScope: 'resident', store: store);
    for (var i = 0; i < 2; i++) {
      await controller.saveSurvey(SurveySession(
        id: 's$i',
        accountScope: 'resident',
        floor: 'B1',
        xPct: .5,
        yPct: 50,
        startedAt: DateTime(2026),
        endedAt: DateTime(2026).add(const Duration(seconds: 15)),
        observations: [
          BeaconObservation(
              beaconId: 'a', rssi: -70, observedAt: DateTime(2026))
        ],
      ));
    }
    expect(controller.sessions, hasLength(2));
    expect(controller.sessions.first.xPct, .5);
    await expectLater(
        controller.saveSurvey(SurveySession(
          id: 'foreign',
          accountScope: 'another',
          floor: 'B1',
          xPct: 50,
          yPct: 50,
          startedAt: DateTime(2026),
          observations: const [],
        )),
        throwsArgumentError);
    controller.dispose();
  });
  testWidgets('current estimate expires without receiving another packet',
      (tester) async {
    var now = DateTime.utc(2026, 11, 23);
    final signals = [
      for (var i = 0; i < 3; i++)
        BeaconObservation(beaconId: 'b$i', rssi: -50 - i * 10, observedAt: now)
    ];
    final store = MemorySurveyStore()
      ..data.add(SurveySession(
          id: 's',
          accountScope: 'resident',
          floor: 'B1',
          xPct: 10,
          yPct: 20,
          startedAt: now,
          endedAt: now,
          observations: signals));
    final observer =
        BeaconObserver(clock: () => now, source: ReadyScanSource());
    final controller = IndoorPositionProvider(
        accountScope: 'resident', observer: observer, store: store);
    await controller.load();
    await controller.start();
    observer.addObservations(signals);
    expect(controller.estimate, isNotNull);
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(controller.estimate, isNull);
    controller.dispose();
    await tester.pump();
    expect(store.closed, isFalse);
  });
  test('older load cannot overwrite newer load or mutate disposed state',
      () async {
    final store = PendingSurveyStore();
    final controller =
        IndoorPositionProvider(accountScope: 'resident', store: store);
    SurveySession sample(String id) => SurveySession(
        id: id,
        accountScope: 'resident',
        floor: 'B1',
        xPct: 10,
        yPct: 20,
        startedAt: DateTime(2026));
    final first = controller.load();
    final second = controller.load();
    store.calls[1].complete([sample('new')]);
    await second;
    store.calls[0].complete([sample('old')]);
    await first;
    expect(controller.sessions.single.id, 'new');
    final third = controller.load();
    controller.dispose();
    store.calls[2].complete([sample('disposed')]);
    await third;
    expect(controller.sessions.single.id, 'new');
    expect(store.closed, isFalse);
  });
}
