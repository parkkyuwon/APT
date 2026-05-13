import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/session.dart';

/// SessionInfo 영속 캐시. 이메일·전화번호 등 PII 포함되므로
/// 반드시 flutter_secure_storage 사용 (Android Keystore / iOS Keychain).
class SessionInfoCache {
  SessionInfoCache._();

  static const _key = 'session_info_v1';

  static FlutterSecureStorage get _storage => AppConfig.secureStorage;

  static Future<void> save(SessionInfo info) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(info.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('[SessionInfoCache] save failed: $e');
    }
  }

  static Future<SessionInfo?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return SessionInfo.fromJson(json);
    } catch (e) {
      if (kDebugMode) debugPrint('[SessionInfoCache] load failed: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      if (kDebugMode) debugPrint('[SessionInfoCache] clear failed: $e');
    }
  }
}
