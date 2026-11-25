import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/indoor_positioning.dart';

/// Device-local raw surveys; never writes the server's beacon position contract.
class IndoorSurveyStore {
  final DatabaseFactory? _providedFactory;
  DatabaseFactory get _factory => _providedFactory ?? databaseFactory;
  final String? _path;
  Future<Database>? _opening;
  IndoorSurveyStore({DatabaseFactory? factory, String? path})
      : _providedFactory = factory,
        _path = path;
  Future<Database> _db() async {
    final opening = _opening ??= _open();
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final path =
        _path ?? '${await _factory.getDatabasesPath()}/indoor_surveys_v1.db';
    return _factory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 3,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: (db, version) async {
              await db.execute(
                  "CREATE TABLE survey_sessions (account_scope TEXT NOT NULL, id TEXT NOT NULL, site_id TEXT NOT NULL, floor TEXT NOT NULL CHECK(floor IN ('B1','B2')), payload TEXT NOT NULL, PRIMARY KEY(account_scope,id))");
              await db.execute(
                  'CREATE TABLE beacon_observations (account_scope TEXT NOT NULL, survey_id TEXT NOT NULL, ordinal INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(account_scope,survey_id,ordinal), FOREIGN KEY(account_scope,survey_id) REFERENCES survey_sessions(account_scope,id) ON DELETE CASCADE)');
              await db.execute(
                  'CREATE INDEX survey_site ON survey_sessions(account_scope,site_id)');
              await _createPublishedCache(db);
              await _createFloorIndex(db);
            },
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion < 2) await _createPublishedCache(db);
              if (oldVersion < 3) await _migrateSurveyFloors(db);
            }));
  }

  static Future<void> _createPublishedCache(Database db) => db.execute(
      'CREATE TABLE published_indoor_datasets (cache_scope TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL)');

  static Future<void> _createFloorIndex(Database db) => db.execute(
      'CREATE INDEX survey_floor ON survey_sessions(account_scope,floor,site_id)');

  static Future<void> _migrateSurveyFloors(Database db) async {
    // sqflite runs onUpgrade transactionally: invalid old metadata rolls back
    // the schema change instead of silently assigning an unknown floor to B1.
    final rows = await db
        .query('survey_sessions', columns: ['account_scope', 'id', 'payload']);
    final floors = <String>[];
    for (final row in rows) {
      final metadata = jsonDecode(row['payload'] as String);
      if (metadata is! Map || !const ['B1', 'B2'].contains(metadata['floor'])) {
        throw const FormatException('Unsupported floor in stored survey.');
      }
      floors.add(metadata['floor'] as String);
    }
    await db.execute(
        "ALTER TABLE survey_sessions ADD COLUMN floor TEXT NOT NULL DEFAULT 'B1' CHECK(floor IN ('B1','B2'))");
    final batch = db.batch();
    for (var i = 0; i < rows.length; i++) {
      batch.update('survey_sessions', {'floor': floors[i]},
          where: 'account_scope = ? AND id = ?',
          whereArgs: [rows[i]['account_scope'], rows[i]['id']]);
    }
    await batch.commit(noResult: true);
    await _createFloorIndex(db);
  }

  static void _validateFloor(String floor) {
    if (!const ['B1', 'B2'].contains(floor)) {
      throw ArgumentError.value(floor, 'floor', 'Expected B1 or B2.');
    }
  }

  /// Caller validates the API contract before activation. Scope includes server
  /// environment and authenticated account, and remains separate from surveys.
  Future<Map<String, dynamic>?> loadPublished(String cacheScope) async {
    final db = await _db();
    final rows = await db.query('published_indoor_datasets',
        where: 'cache_scope = ?', whereArgs: [cacheScope]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(
        jsonDecode(rows.single['payload'] as String) as Map);
  }

  Future<void> savePublished(
      String cacheScope, Map<String, dynamic> dataset) async {
    if (cacheScope.isEmpty) {
      throw ArgumentError('Published cache scope must not be empty.');
    }
    final encoded = jsonEncode(dataset);
    final db = await _db();
    await db.insert('published_indoor_datasets',
        {'cache_scope': cacheScope, 'payload': encoded},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePublished(String cacheScope) async {
    final db = await _db();
    await db.delete('published_indoor_datasets',
        where: 'cache_scope = ?', whereArgs: [cacheScope]);
  }

  Future<void> save(SurveySession session) async {
    _validateFloor(session.floor);
    final db = await _db();
    final metadata = session.toJson()..remove('observations');
    await db.transaction((txn) async {
      await txn.delete('survey_sessions',
          where: 'account_scope = ? AND id = ?',
          whereArgs: [session.accountScope, session.id]);
      await txn.insert('survey_sessions', {
        'account_scope': session.accountScope,
        'id': session.id,
        'site_id': session.siteId,
        'floor': session.floor,
        'payload': jsonEncode(metadata)
      });
      final batch = txn.batch();
      for (var i = 0; i < session.observations.length; i++) {
        batch.insert('beacon_observations', {
          'account_scope': session.accountScope,
          'survey_id': session.id,
          'ordinal': i,
          'payload': jsonEncode(session.observations[i].toJson())
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<SurveySession>> load(String accountScope, {String? siteId}) =>
      _load(accountScope, siteId: siteId);

  /// Retrieves only the requested floor using its persisted, indexed column.
  Future<List<SurveySession>> loadFloor(String accountScope, String floor,
      {String? siteId}) async {
    _validateFloor(floor);
    return _load(accountScope, siteId: siteId, floor: floor);
  }

  Future<List<SurveySession>> _load(String accountScope,
      {String? siteId, String? floor}) async {
    if (accountScope.isEmpty) return [];
    final db = await _db();
    return db.transaction((txn) async {
      final rows = await txn.query('survey_sessions',
          where:
              'account_scope = ?${siteId == null ? '' : ' AND site_id = ?'}${floor == null ? '' : ' AND floor = ?'}',
          whereArgs: [
            accountScope,
            if (siteId != null) siteId,
            if (floor != null) floor
          ],
          orderBy: 'rowid');
      final sessions = <SurveySession>[];
      for (final row in rows) {
        final metadata = Map<String, dynamic>.from(
            jsonDecode(row['payload'] as String) as Map);
        if (metadata['accountScope'] != accountScope ||
            metadata['id'] != row['id'] ||
            metadata['siteId'] != row['site_id'] ||
            metadata['floor'] != row['floor']) {
          throw const FormatException('Survey ownership metadata mismatch.');
        }
        final packets = await txn.query('beacon_observations',
            where: 'account_scope = ? AND survey_id = ?',
            whereArgs: [accountScope, row['id']],
            orderBy: 'ordinal');
        metadata['observations'] =
            packets.map((p) => jsonDecode(p['payload'] as String)).toList();
        sessions.add(SurveySession.fromJson(metadata));
      }
      return sessions;
    });
  }

  Future<void> delete(String accountScope, String id) async {
    final db = await _db();
    await db.delete('survey_sessions',
        where: 'account_scope = ? AND id = ?', whereArgs: [accountScope, id]);
  }

  Future<void> setExcluded(
      String accountScope, String id, bool excluded) async {
    final db = await _db();
    await db.transaction((txn) async {
      final rows = await txn.query('survey_sessions',
          where: 'account_scope = ? AND id = ?', whereArgs: [accountScope, id]);
      if (rows.isEmpty) return;
      final data = Map<String, dynamic>.from(
          jsonDecode(rows.single['payload'] as String) as Map);
      data['excluded'] = excluded;
      await txn.update('survey_sessions', {'payload': jsonEncode(data)},
          where: 'account_scope = ? AND id = ?', whereArgs: [accountScope, id]);
    });
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) {
      Database database;
      try {
        database = await opening;
      } catch (_) {
        // The operation that opened it already reports this error. Disposal
        // must not rethrow a handled failure from an unawaited cleanup.
        return;
      }
      await database.close();
    }
  }
}
