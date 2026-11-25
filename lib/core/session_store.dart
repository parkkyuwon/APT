import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 세션 쿠키를 flutter_secure_storage 에 보관하는 [PersistCookieJar] 대체 구현.
///
/// cookie_jar 의 FileStorage 는 path_provider 에 의존하며 앱 샌드박스 파일을
/// 평문으로 기록한다. 본 앱은 세션 쿠키를 민감 정보로 취급하므로 Keystore/Keychain
/// 기반 저장소를 사용한다.
class SecureCookieJar implements CookieJar {
  SecureCookieJar(
      {FlutterSecureStorage? storage, this.storageKey = 'cookies.v1'})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final String storageKey;
  final DefaultCookieJar _memoryJar = DefaultCookieJar();
  bool _loaded = false;
  Future<void> _operations = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = await _storage.read(key: storageKey);
    if (raw != null && raw.isNotEmpty) {
      for (final line in raw.split('\n')) {
        if (line.isEmpty) continue;
        final sep = line.indexOf('|');
        if (sep <= 0) continue;
        final uriPart = line.substring(0, sep);
        final cookiePart = line.substring(sep + 1);
        try {
          final cookie = Cookie.fromSetCookieValue(cookiePart);
          await _memoryJar.saveFromResponse(Uri.parse(uriPart), [cookie]);
        } catch (_) {
          // 파싱 실패 쿠키는 무시
        }
      }
    }
    _loaded = true;
  }

  Future<void> _persist(Uri uri, List<Cookie> cookies) async {
    final existing = await _storage.read(key: storageKey) ?? '';
    final buffer = StringBuffer(existing);
    for (final c in cookies) {
      if (buffer.isNotEmpty && !existing.endsWith('\n')) buffer.write('\n');
      buffer
        ..write(uri.toString())
        ..write('|')
        ..write(c.toString())
        ..write('\n');
    }
    await _storage.write(key: storageKey, value: buffer.toString());
  }

  Future<void> _delete(Uri uri, [bool withDomainSharedCookie = false]) async {
    await _ensureLoaded();
    await _memoryJar.delete(uri, withDomainSharedCookie);
    await _storage.delete(key: storageKey);
    // 남은 쿠키들을 다시 저장
    final all = await _memoryJar.loadForRequest(uri);
    if (all.isNotEmpty) await _persist(uri, all);
  }

  Future<void> _deleteAll() async {
    await _memoryJar.deleteAll();
    await _storage.delete(key: storageKey);
    _loaded = true;
  }

  Future<List<Cookie>> _loadForRequest(Uri uri) async {
    await _ensureLoaded();
    return _memoryJar.loadForRequest(uri);
  }

  Future<void> _saveFromResponse(Uri uri, List<Cookie> cookies) async {
    await _ensureLoaded();
    if (cookies.isEmpty) return;
    await _memoryJar.saveFromResponse(uri, cookies);
    await _persist(uri, cookies);
  }

  @override
  Future<void> delete(Uri uri, [bool withDomainSharedCookie = false]) =>
      _serialize(() => _delete(uri, withDomainSharedCookie));

  @override
  Future<void> deleteAll() => _serialize(_deleteAll);

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) =>
      _serialize(() => _loadForRequest(uri));

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) =>
      _serialize(() => _saveFromResponse(uri, cookies));

  @override
  bool get ignoreExpires => _memoryJar.ignoreExpires;
}
