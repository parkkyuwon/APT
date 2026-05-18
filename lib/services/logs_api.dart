import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/activity_log.dart';

/// /api/logs — 관리자 전용 활동 로그 조회.
class LogsApi {
  LogsApi(this._client);
  final ApiClient _client;

  Future<List<ActivityLog>> list({int limit = 100}) async {
    try {
      final res = await _client.dio.get<dynamic>(
        '/api/logs',
        queryParameters: {'limit': limit},
      );
      final body = await _client.requireOk(res);
      return asListOfMaps(body['logs'])
          .map(ActivityLog.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}
