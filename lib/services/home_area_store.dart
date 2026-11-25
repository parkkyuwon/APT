import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/home_area.dart';

/// Uses OS protected storage; no preferences or server coordinate copies.
class HomeAreaStore {
  HomeAreaStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  Future<void> _pending = Future<void>.value();
  String _key(String scope) {
    if (scope.trim().isEmpty) throw ArgumentError('Account required');
    return 'home-area.v1.${base64Url.encode(utf8.encode(scope))}';
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<HomeArea?> load(String accountScope) => _serial(() async {
        final raw = await _storage.read(key: _key(accountScope));
        if (raw == null) return null;
        try {
          final area =
              HomeArea.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          return area.accountScope == accountScope ? area : null;
        } on FormatException {
          return null;
        } on TypeError {
          return null;
        } on ArgumentError {
          return null;
        }
      });
  Future<void> save(HomeArea area) => _serial(() => _storage.write(
      key: _key(area.accountScope), value: jsonEncode(area.toJson())));
  Future<void> delete(String accountScope) =>
      _serial(() => _storage.delete(key: _key(accountScope)));
}
