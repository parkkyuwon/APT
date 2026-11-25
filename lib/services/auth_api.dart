import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/session.dart';

/// /api/auth — Google 로그인 / 관리자 ID/PW 로그인 / 로그아웃.
class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  /// GET /api/auth — 현재 세션 조회 (쿠키 기반).
  Future<AuthBootstrap> fetchSession() async {
    try {
      final res = await _client.dio.get<dynamic>('/api/auth');
      final body = await _client.requireOk(res);
      return AuthBootstrap.fromJson(body);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/auth — Google idToken 으로 로그인.
  Future<AuthBootstrap> loginWithGoogle(String idToken) async {
    try {
      final res = await _client.dio.post<dynamic>(
        '/api/auth',
        data: {'googleCredential': idToken},
      );
      final body = await _client.requireOk(res);
      return AuthBootstrap.fromJson(body);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  // Phase 8.2: 관리자 ID/PW 로그인 (loginWithPassword) 제거.
  // 백엔드의 ADMIN_ID/ADMIN_PW 환경변수가 폐기되었으며, Google 로그인 + ADMIN_EMAILS
  // 허용목록을 통해서만 관리자 권한을 부여한다.

  /// POST /api/auth { action: "logout" } — 서버 세션 해제.
  Future<void> logout() async {
    try {
      final res = await _client.dio.post<dynamic>(
        '/api/auth',
        data: {'action': 'logout'},
      );
      await _client.requireOk(res);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    } finally {
      // 서버 거절(ApiException)과 네트워크 오류에도 로컬 세션을 제거한다.
      await _client.clearSession();
    }
  }
}
