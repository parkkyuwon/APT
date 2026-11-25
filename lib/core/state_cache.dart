import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/app_state.dart';

/// SharedPreferences 기반 AppState 영속 캐시.
/// 콜드 스타트 시 마지막으로 본 상태를 즉시 화면에 표시하고,
/// 백그라운드에서 서버 응답 도착 시 갱신하는 stale-while-revalidate 패턴 지원.
class StateCache {
  StateCache._();

  static const _key = 'app_state_v1';
  static const _tsKey = 'app_state_v1_ts';
  static const _ownerKey = 'app_state_owner_v1';
  static Future<void> _pendingWrite = Future<void>.value();

  // 저장 도중 로그아웃이 발생해도 마지막 clear가 이전 save보다 뒤에 실행된다.
  static Future<void> _enqueue(Future<void> Function() operation) {
    final next = _pendingWrite.then((_) => operation());
    _pendingWrite = next.catchError((Object error) {
      if (kDebugMode) debugPrint('[StateCache] write failed: $error');
    });
    return _pendingWrite;
  }

  static Future<void> save(AppState state, {String? owner}) =>
      _enqueue(() async {
        try {
          final p = AppConfig.prefs;
          // Keep ownership and payload atomic, including during a delayed write.
          await p.setString(
              _key, jsonEncode({'owner': owner, 'state': state.toJson()}));
          await p.setInt(_tsKey, DateTime.now().millisecondsSinceEpoch);
          await p.remove(_ownerKey);
        } catch (e) {
          if (kDebugMode) debugPrint('[StateCache] save failed: $e');
        }
      });

  static AppState? load({String? owner}) {
    try {
      final raw = AppConfig.prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      if (json.containsKey('state')) {
        if (owner != null && json['owner'] != owner) return null;
        final state = json['state'];
        return state is Map<String, dynamic> ? AppState.fromJson(state) : null;
      }
      // Older payloads cannot prove member ownership, even with a separate key.
      if (owner != null) return null;
      return AppState.fromJson(json);
    } catch (e) {
      if (kDebugMode) debugPrint('[StateCache] load failed: $e');
      return null;
    }
  }

  static DateTime? cachedAt() {
    final ms = AppConfig.prefs.getInt(_tsKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> clear() => _enqueue(() async {
        final p = AppConfig.prefs;
        await p.remove(_key);
        await p.remove(_tsKey);
        await p.remove(_ownerKey);
      });
}
