import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/parking_history.dart';
import '../models/user.dart';

/// /api/my-history — 본인 주차 이력 (+ 관리자 전용 타 사용자 이력 조회).
class MyHistoryApi {
  MyHistoryApi(this._client);
  final ApiClient _client;

  Future<MyHistoryResult> fetchMine({String? from, String? to}) async {
    try {
      final res = await _client.dio.get<dynamic>(
        '/api/my-history',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );
      final body = await _client.requireOk(res);
      final userJson = (body['user'] as Map?)?.cast<String, dynamic>();
      final list = (body['history'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return MyHistoryResult(
        user: userJson == null ? null : AppUser.fromJson(userJson),
        records: list.map(ParkingHistoryRecord.fromJson).toList(growable: false),
      );
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// 관리자 전용 — 타 사용자 이력 페이지네이션.
  Future<AdminHistoryPage> fetchForUser({
    required String email,
    String? from,
    String? to,
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      final res = await _client.dio.get<dynamic>(
        '/api/my-history',
        queryParameters: {
          'email': email,
          'offset': offset,
          'limit': limit,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );
      final body = await _client.requireOk(res);
      final list = (body['records'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return AdminHistoryPage(
        records: list.map(ParkingHistoryRecord.fromJson).toList(growable: false),
        hasMore: body['hasMore'] == true,
        offset: (body['offset'] as num?)?.toInt() ?? offset,
        limit: (body['limit'] as num?)?.toInt() ?? limit,
      );
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}

class MyHistoryResult {
  MyHistoryResult({required this.user, required this.records});
  final AppUser? user;
  final List<ParkingHistoryRecord> records;
}

class AdminHistoryPage {
  AdminHistoryPage({
    required this.records,
    required this.hasMore,
    required this.offset,
    required this.limit,
  });
  final List<ParkingHistoryRecord> records;
  final bool hasMore;
  final int offset;
  final int limit;
}
