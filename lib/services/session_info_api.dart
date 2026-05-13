import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/session.dart';

/// /api/session-admin — 관리자 페이지용 세션 + 승인대기 목록.
class SessionAdminApi {
  SessionAdminApi(this._client);
  final ApiClient _client;

  Future<AuthBootstrap> fetch() async {
    try {
      final res = await _client.dio.get<dynamic>('/api/session-admin');
      final body = await _client.requireOk(res);
      return AuthBootstrap.fromJson(body);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}

/// /api/session-public — 사용자 페이지용 세션 (needsConsent/needsPhotoVerification 포함).
class SessionPublicApi {
  SessionPublicApi(this._client);
  final ApiClient _client;

  Future<AuthBootstrap> fetch() async {
    try {
      final res = await _client.dio.get<dynamic>('/api/session-public');
      final body = await _client.requireOk(res);
      return AuthBootstrap.fromJson(body);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}
