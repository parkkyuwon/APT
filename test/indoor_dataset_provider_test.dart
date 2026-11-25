import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:apt_ev_charging/core/errors.dart';
import 'package:apt_ev_charging/models/indoor_positioning.dart';
import 'package:apt_ev_charging/models/app_state.dart';
import 'package:apt_ev_charging/models/published_indoor_dataset.dart';
import 'package:apt_ev_charging/providers/indoor_dataset_provider.dart';
import 'package:apt_ev_charging/services/indoor_positioning_api.dart';
import 'package:apt_ev_charging/services/indoor_survey_store.dart';

class FakeIndoorApi implements IndoorPositioningApi {
  Map<String, BeaconPosition>? lastBeaconPositions;
  Future<PublishedIndoorDataset> Function()? fetcher;
  Future<PublishedIndoorDataset> Function(int, bool, List<SurveySession>)?
      publisher;
  @override
  Future<PublishedIndoorDataset> fetch() => fetcher!();
  @override
  Future<PublishedIndoorDataset> publish(
      {required int expectedRevision,
      required bool enabled,
      required List<SurveySession> surveys,
      Map<String, BeaconPosition>? beaconPositions}) {
    lastBeaconPositions = beaconPositions;
    return publisher!(expectedRevision, enabled, surveys);
  }
}

class FailingCache extends IndoorSurveyStore {
  FailingCache()
      : super(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  bool fail = false;
  @override
  Future<void> savePublished(String scope, Map<String, dynamic> dataset) async {
    if (fail) throw StateError('Disk unavailable');
    await super.savePublished(scope, dataset);
  }
}

void main() {
  sqfliteFfiInit();
  late FakeIndoorApi api;
  late FailingCache store;
  late IndoorDatasetProvider provider;
  final now = DateTime.utc(2026, 11, 23);
  final survey = SurveySession(
      id: 's',
      accountScope: 'published',
      floor: 'B1',
      xPct: 10,
      yPct: 20,
      startedAt: now,
      endedAt: now,
      observations: [
        BeaconObservation(beaconId: 'b', rssi: -60, observedAt: now)
      ]);
  PublishedIndoorDataset dataset(int revision, {bool enabled = true}) =>
      PublishedIndoorDataset(revision: revision, enabled: enabled, surveys: [
        survey
      ], beaconPositions: const {
        'installed': BeaconPosition(floor: 'B1', x: .5, y: 20)
      });
  setUp(() {
    api = FakeIndoorApi();
    store = FailingCache();
    provider =
        IndoorDatasetProvider(api, cacheScope: 'test:account', store: store);
  });
  tearDown(() async {
    provider.dispose();
    await store.close();
  });
  test('cache is available while newest server fetch is pending then updates',
      () async {
    await store.savePublished('test:account', dataset(1).toJson());
    final remote = Completer<PublishedIndoorDataset>();
    api.fetcher = () => remote.future;
    final refresh = provider.refresh();
    while (provider.dataset == null) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(provider.available, isTrue);
    expect(provider.loading, isTrue);
    remote.complete(dataset(2));
    await refresh;
    expect(provider.dataset!.revision, 2);
    expect(provider.error, isNull);
    expect((await store.loadPublished('test:account'))!['revision'], 2);
  });
  test('404/500 fallback preserves last valid cache and reports offline',
      () async {
    await store.savePublished('test:account', dataset(3).toJson());
    for (final status in [404, 500]) {
      api.fetcher = () async =>
          throw ApiException(statusCode: status, message: 'unavailable');
      await provider.refresh();
      expect(provider.available, isTrue);
      expect(provider.dataset!.revision, 3);
      expect(provider.offline, isTrue);
    }
  });
  test('401 and 403 clear both memory and cache', () async {
    await store.savePublished('test:account', dataset(3).toJson());
    api.fetcher =
        () async => throw ApiException(statusCode: 403, message: 'denied');
    await provider.refresh();
    expect(provider.dataset, isNull);
    expect(await store.loadPublished('test:account'), isNull);
  });
  test('regression or malformed server data does not replace cache', () async {
    await store.savePublished('test:account', dataset(3).toJson());
    api.fetcher = () async => dataset(2);
    await provider.refresh();
    expect(provider.dataset!.revision, 3);
    expect(provider.error, isNotNull);
    api.fetcher = () async => throw const FormatException('bad data');
    await provider.refresh();
    expect(provider.dataset!.revision, 3);
    expect((await store.loadPublished('test:account'))!['revision'], 3);
  });
  test('server disable takes effect even when persistence fails', () async {
    await store.savePublished('test:account', dataset(3).toJson());
    store.fail = true;
    api.fetcher = () async => dataset(4, enabled: false);
    await provider.refresh();
    expect(provider.available, isFalse);
    expect(provider.dataset!.revision, 4);
    expect(provider.error, isNotNull);
  });
  test(
      'wrong site, floor, duplicate ids and excessive observations keep valid cache',
      () async {
    await store.savePublished('test:account', dataset(3).toJson());
    SurveySession variant(
            {String siteId = 'home', String floor = 'B1', int count = 1}) =>
        SurveySession(
            id: 'other',
            accountScope: 'published',
            siteId: siteId,
            floor: floor,
            xPct: 10,
            yPct: 20,
            startedAt: now,
            endedAt: now,
            observations: List.filled(count, survey.observations.single));
    for (final records in [
      [variant(siteId: 'different')],
      [variant(floor: 'B99')],
      [survey, survey],
      [variant(count: 20001)]
    ]) {
      api.fetcher = () async =>
          PublishedIndoorDataset(revision: 4, enabled: true, surveys: records);
      await provider.refresh();
      expect(provider.dataset!.revision, 3);
      expect(provider.error, isNotNull);
    }
  });
  test('publish uses known revision and conflict preserves server dataset',
      () async {
    api.fetcher = () async => dataset(3);
    await provider.refresh();
    api.publisher = (revision, enabled, surveys) async {
      expect(revision, 3);
      expect(enabled, isFalse);
      throw ApiException(statusCode: 409, message: 'conflict');
    };
    expect(await provider.publish(enabled: false, surveys: [survey]), isFalse);
    expect(api.lastBeaconPositions!['installed']!.x, .5);
    expect(provider.dataset!.enabled, isTrue);
    expect(provider.dataset!.revision, 3);
    api.publisher =
        (revision, enabled, surveys) async => dataset(4, enabled: false);
    expect(await provider.publish(enabled: false, surveys: [survey]), isTrue);
    expect(provider.available, isFalse);
    expect(provider.dataset!.revision, 4);
  });
  test('disposed provider ignores pending fetch and preserves shared store',
      () async {
    final pending = Completer<PublishedIndoorDataset>();
    api.fetcher = () => pending.future;
    final disposable =
        IndoorDatasetProvider(api, cacheScope: 'other', store: store);
    final refresh = disposable.refresh();
    await Future<void>.delayed(Duration.zero);
    disposable.dispose();
    pending.complete(dataset(5));
    await refresh;
    expect(disposable.dataset, isNull);
    expect(await store.loadPublished('other'), isNull);
    await store.savePublished('usable', dataset(1).toJson());
  });
  test(
      'installed positions survive server cache and reject malformed coordinates',
      () async {
    final original = dataset(3);
    final restored = PublishedIndoorDataset.fromJson(original.toJson());
    expect(restored.beaconPositions['installed']!.x, .5);
    expect(
        () => PublishedIndoorDataset.fromJson({
              ...original.toJson(),
              'beaconPositions': {
                'bad': {'floor': 'B1', 'x': 'oops', 'y': 30}
              }
            }),
        throwsFormatException);
    expect(
        () => PublishedIndoorDataset(revision: 4, enabled: true, surveys: [
              survey
            ], beaconPositions: const {
              'bad': BeaconPosition(floor: 'B99', x: 10, y: 20)
            }),
        throwsFormatException);
  });
}
