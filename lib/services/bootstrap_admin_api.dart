import 'package:dio/dio.dart';

import '../core/api_client.dart';

/// /api/bootstrap-admin — 최초 관리자 설정 (SUPER_ADMIN_EMAIL).
///
/// 응답 형태는 서버 구현체 참조. 성공/실패 bool 만 관리자 화면에 표시.
class BootstrapAdminApi {
  BootstrapAdminApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> run() async {
    try {
      final res = await _client.dio.post<dynamic>('/api/bootstrap-admin');
      final body = await _client.requireOk(res);
      return body;
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}
