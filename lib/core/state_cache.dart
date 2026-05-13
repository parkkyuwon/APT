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

  static Future<void> save(AppState state) async {
    try {
      final p = AppConfig.prefs;
      await p.setString(_key, jsonEncode(state.toJson()));
      await p.setInt(_tsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) debugPrint('[StateCache] save failed: $e');
    }
  }

  static AppState? load() {
    try {
      final raw = AppConfig.prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
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

  static Future<void> clear() async {
    final p = AppConfig.prefs;
    await p.remove(_key);
    await p.remove(_tsKey);
  }
}
