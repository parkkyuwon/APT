import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/user.dart';

/// /api/users — 관리자 전용 회원 관리.
class UsersApi {
  UsersApi(this._client);
  final ApiClient _client;

  /// GET /api/users?status=...&view=full|summary&limit=100&offset=0
  Future<List<AppUser>> list({
    String? status,
    String view = 'full',
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final res = await _client.dio.get<dynamic>(
        '/api/users',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          'view': view,
          'limit': limit,
          'offset': offset,
        },
      );
      final body = await _client.requireOk(res);
      final list = (body['users'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return list.map(AppUser.fromJson).toList(growable: false);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/users — 회원 상태 변경 (pending/approved/rejected/blocked/withdrawn)
  Future<void> updateAccess({
    required String email,
    required String status,
    String role = 'user',
  }) async {
    try {
      final res = await _client.dio.post<dynamic>(
        '/api/users',
        data: {'email': email, 'status': status, 'role': role},
      );
      await _client.requireOk(res);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/users { action: "verify-vehicle" } — 차량 사진 승인/거절
  Future<void> verifyVehicle({required String email, required bool approved}) async {
    try {
      final res = await _client.dio.post<dynamic>(
        '/api/users',
        data: {'email': email, 'action': 'verify-vehicle', 'approved': approved},
      );
      await _client.requireOk(res);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}
