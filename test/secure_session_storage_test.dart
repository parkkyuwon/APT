// The storage package exposes this platform seam transitively, so the test can
// control the production AppConfig-backed cache without adding a runtime dep.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:apt_ev_charging/core/api_client.dart';
import 'package:apt_ev_charging/core/session_info_cache.dart';
import 'package:apt_ev_charging/core/errors.dart';
import 'package:apt_ev_charging/core/session_store.dart';
import 'package:apt_ev_charging/models/session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/controlled_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DelayedSecureStoragePlatform platform;

  setUp(() {
    platform = DelayedSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = platform;
  });

  tearDown(() {
    platform.dispose();
  });

  test('session info clear waits for an in-flight save', () async {
    final save = SessionInfoCache.save(_session());
    await platform.writeStarted.future;

    var clearCompleted = false;
    final clear = SessionInfoCache.clear().then((_) => clearCompleted = true);
    try {
      await Future<void>.delayed(Duration.zero);
      expect(clearCompleted, isFalse);
    } finally {
      platform.finishWrite();
      await Future.wait([save, clear]);
    }

    expect(platform.values, isEmpty);
  });

  test('cookie jar clear waits for an in-flight save', () async {
    final storage = DelayedSecureStorage();
    final jar = SecureCookieJar(storage: storage);
    final uri = Uri.parse('https://example.test/api');
    final save = jar.saveFromResponse(uri, [Cookie('session', 'opaque')]);
    await storage.writeStarted.future;

    var clearCompleted = false;
    final clear = jar.deleteAll().then((_) => clearCompleted = true);
    try {
      await Future<void>.delayed(Duration.zero);
      expect(clearCompleted, isFalse);
    } finally {
      storage.finishWrite();
      await Future.wait([save, clear]);
    }

    expect(storage.values, isEmpty);
    expect(await jar.loadForRequest(uri), isEmpty);
  });

  test('response stalled in CookieManager cannot refill ETag after clear',
      () async {
    final client = await ApiClient.init();
    final transport = ControlledApi();
    addTearDown(transport.close);
    client.dio.httpClientAdapter = transport;

    final request = client.dio.get('/api/state');
    final pending = await transport.next();
    pending.response.complete(ResponseBody.fromString(
      '{"ok":true,"state":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'etag': ['old-session-etag'],
        'set-cookie': ['session=opaque; Path=/'],
      },
    ));
    await platform.writeStarted.future;

    final clear = client.clearSession();
    try {
      platform.finishWrite();
      await clear;
      try {
        await request;
      } on Exception {
        // Rejecting the invalidated response is an allowed outcome.
      }
    } finally {
      platform.finishWrite();
      await clear;
    }

    expect(client.etagCache.getEtag('/api/state'), isNull);
    expect(
        await client.cookieJar
            .loadForRequest(Uri.parse(client.dio.options.baseUrl)),
        isEmpty);
    expect(platform.values, isEmpty);
  });
}

SessionInfo _session() => SessionInfo(
      email: 'member@example.test',
      name: 'Member',
      nickname: 'Member',
      picture: '',
      role: 'user',
      status: AuthStatus.approved,
      approved: true,
      authType: 'google',
      vehicleNumber: '',
      profileComplete: true,
    );

class DelayedSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> values = {};
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> _writeGate = Completer<void>();

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await _writeGate.future;
    values[key] = value;
  }

  void finishWrite() {
    if (!_writeGate.isCompleted) _writeGate.complete();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      values[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of(values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    values.clear();
  }

  void dispose() {
    if (!_writeGate.isCompleted) _writeGate.complete();
  }
}

class DelayedSecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> _writeGate = Completer<void>();

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await _writeGate.future;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  void finishWrite() {
    if (!_writeGate.isCompleted) _writeGate.complete();
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
