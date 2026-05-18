import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/app_state.dart';

/// /api/state — 주차 현황 전체 조회/변경.
///
/// - GET: approved 세션 필수. 현재 [AppState] 반환. ETag 자동 처리 (304 → 캐시)
/// - POST: approved 세션 필수. 일반 사용자는 본인 슬롯만, 관리자는 전체 상태 덮어쓰기
class StateApi {
  StateApi(this._client);
  final ApiClient _client;

  Future<AppState> fetch() async {
    try {
      final res = await _client.dio.get<dynamic>('/api/state');
      final body = await _client.requireOk(res);
      return AppState.fromJson(asMapOrNull(body['state']) ?? const {});
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/state — payload 는 서버 [AppState] JSON 형식.
  /// 일반 사용자: 본인 차량 주차 등록/해제. 관리자: 전체 상태 교체.
  Future<AppState> save(Map<String, dynamic> payload) async {
    try {
      _client.etagCache.invalidate('/api/state');
      final res = await _client.dio.post<dynamic>('/api/state', data: payload);
      final body = await _client.requireOk(res);
      return AppState.fromJson(asMapOrNull(body['state']) ?? const {});
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}
