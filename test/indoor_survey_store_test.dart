import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:apt_ev_charging/models/indoor_positioning.dart';
import 'package:apt_ev_charging/services/indoor_survey_store.dart';

class _UnavailableDatabase implements DatabaseFactory {
  @override
  Future<Database> openDatabase(String path,
          {OpenDatabaseOptions? options}) async =>
      throw StateError('Database unavailable');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('closing after a handled database open failure does not rethrow',
      () async {
    final store =
        IndoorSurveyStore(factory: _UnavailableDatabase(), path: 'unavailable');
    await expectLater(store.loadPublished('account'), throwsStateError);
    await expectLater(store.close(), completes);
  });
  sqfliteFfiInit();
  late IndoorSurveyStore store;
  final now = DateTime.utc(2026, 11, 23);
  SurveySession sample(String scope, String id, {String floor = 'B1'}) =>
      SurveySession(
          id: id,
          accountScope: scope,
          floor: floor,
          xPct: .5,
          yPct: 30,
          startedAt: now,
          endedAt: now,
          observations: [
            BeaconObservation(beaconId: 'b', rssi: -60, observedAt: now)
          ]);
  setUp(() => store = IndoorSurveyStore(
      factory: databaseFactoryFfi, path: inMemoryDatabasePath));
  tearDown(() => store.close());
  test('B1 and B2 retain separate fingerprints at identical coordinates',
      () async {
    await store.save(sample('a', 'b1'));
    await store.save(sample('a', 'b2', floor: 'B2'));
    expect((await store.loadFloor('a', 'B1')).single.id, 'b1');
    expect((await store.loadFloor('a', 'B2')).single.id, 'b2');
    expect(await store.loadFloor('a', 'B2', siteId: 'other'), isEmpty);
    await store.setExcluded('a', 'b1', true);
    expect((await store.loadFloor('a', 'B1')).single.excluded, isTrue);
    expect((await store.loadFloor('a', 'B2')).single.excluded, isFalse);
    await store.delete('a', 'b1');
    expect(await store.loadFloor('a', 'B1'), isEmpty);
    expect(
        (await store.loadFloor('a', 'B2')).single.observations.single.beaconId,
        'b');
    await expectLater(store.loadFloor('a', 'B99'), throwsArgumentError);
  });
  test('v2 migration backfills persisted floor and preserves published cache',
      () async {
    final dir = await Directory.systemTemp.createTemp('apt-survey-floor-');
    final path = '${dir.path}/floor.db';
    final old = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 2,
            onCreate: (db, version) async {
              await db.execute(
                  'CREATE TABLE survey_sessions (account_scope TEXT NOT NULL,id TEXT NOT NULL,site_id TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(account_scope,id))');
              await db.execute(
                  'CREATE TABLE beacon_observations (account_scope TEXT NOT NULL,survey_id TEXT NOT NULL,ordinal INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(account_scope,survey_id,ordinal))');
              await db.execute(
                  'CREATE TABLE published_indoor_datasets (cache_scope TEXT PRIMARY KEY NOT NULL,payload TEXT NOT NULL)');
            }));
    for (final floor in ['B1', 'B2']) {
      final session = sample('a', floor, floor: floor);
      final metadata = session.toJson()..remove('observations');
      await old.insert('survey_sessions', {
        'account_scope': 'a',
        'id': floor,
        'site_id': 'home',
        'payload': jsonEncode(metadata)
      });
      await old.insert('beacon_observations', {
        'account_scope': 'a',
        'survey_id': floor,
        'ordinal': 0,
        'payload': jsonEncode(session.observations.single.toJson())
      });
    }
    await old.insert('published_indoor_datasets',
        {'cache_scope': 'shared', 'payload': '{"revision":7}'});
    await old.close();
    final upgraded = IndoorSurveyStore(factory: databaseFactoryFfi, path: path);
    try {
      for (final floor in ['B1', 'B2']) {
        final result = (await upgraded.loadFloor('a', floor)).single;
        expect(result.floor, floor);
        expect(result.id, floor);
        expect(result.xPct, .5);
      }
      expect(await upgraded.loadPublished('shared'), {'revision': 7});
      final db = await databaseFactoryFfi.openDatabase(path);
      expect(await db.getVersion(), 3);
      expect(
          (await db
                  .rawQuery('SELECT floor FROM survey_sessions ORDER BY floor'))
              .map((r) => r['floor']),
          ['B1', 'B2']);
    } finally {
      await upgraded.close();
      await databaseFactoryFfi.deleteDatabase(path);
      await dir.delete();
    }
  });
  test(
      'repeated point is separate session and accounts cannot overwrite each other',
      () async {
    await store.save(sample('a', '1'));
    await store.save(sample('a', '2'));
    await store.save(sample('b', '1'));
    expect((await store.load('a')).length, 2);
    await store.setExcluded('a', '1', true);
    expect((await store.load('a')).singleWhere((s) => s.id == '1').excluded,
        isTrue);
    expect((await store.load('b')).single.excluded, isFalse);
    await store.delete('a', '1');
    expect((await store.load('a')).length, 1);
    expect((await store.load('b')).single.xPct, .5);
  });
  test('replacement atomically replaces observations without duplicates',
      () async {
    final sampleA = sample('a', '1');
    await store.save(sampleA);
    await store.save(sampleA);
    expect((await store.load('a')).single.observations.length, 1);
    expect(await store.load('a', siteId: 'different'), isEmpty);
  });
  test('observation failure rolls back prior session replacement', () async {
    await store.save(sample('a', '1'));
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // Inject an actual SQLite constraint failure in the second transaction.
    await db.execute(
        "CREATE TRIGGER reject_packet BEFORE INSERT ON beacon_observations BEGIN SELECT RAISE(ABORT, 'injected'); END");
    await expectLater(
        store.save(sample('a', '1')), throwsA(isA<DatabaseException>()));
    expect((await store.load('a')).single.observations.length, 1);
  });
  test('published dataset cache replaces atomically and isolates scope',
      () async {
    expect(await store.loadPublished('api-a:account'), isNull);
    await store.savePublished('api-a:account', {
      'version': 1,
      'data': [1, 2]
    });
    await store.savePublished('api-b:account', {'version': 7});
    await store.savePublished('api-a:account', {
      'version': 2,
      'data': [3]
    });
    expect(await store.loadPublished('api-a:account'), {
      'version': 2,
      'data': [3]
    });
    await store.deletePublished('api-a:account');
    expect(await store.loadPublished('api-a:account'), isNull);
    expect(await store.loadPublished('api-b:account'), {'version': 7});
  });
  test(
      'schema one upgrade creates published cache and preserves existing surveys',
      () async {
    final dir = await Directory.systemTemp.createTemp('apt-survey-upgrade-');
    final path = '${dir.path}/upgrade.db';
    final old = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute(
                  'CREATE TABLE survey_sessions (account_scope TEXT NOT NULL,id TEXT NOT NULL,site_id TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(account_scope,id))');
              await db.execute(
                  'CREATE TABLE beacon_observations (account_scope TEXT NOT NULL,survey_id TEXT NOT NULL,ordinal INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(account_scope,survey_id,ordinal))');
            }));
    final existing = sample('a', 'existing');
    final metadata = existing.toJson()..remove('observations');
    await old.insert('survey_sessions', {
      'account_scope': 'a',
      'id': 'existing',
      'site_id': 'home',
      'payload': jsonEncode(metadata)
    });
    await old.insert('beacon_observations', {
      'account_scope': 'a',
      'survey_id': 'existing',
      'ordinal': 0,
      'payload': jsonEncode(existing.observations.single.toJson())
    });
    await old.close();
    final upgraded = IndoorSurveyStore(factory: databaseFactoryFfi, path: path);
    try {
      await upgraded.savePublished('scope', {'version': 1});
      expect((await upgraded.load('a')).single.id, 'existing');
      expect(await upgraded.loadPublished('scope'), {'version': 1});
    } finally {
      await upgraded.close();
      await databaseFactoryFfi.deleteDatabase(path);
      await dir.delete();
    }
  });
}
