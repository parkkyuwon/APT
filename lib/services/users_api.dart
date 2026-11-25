import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/user.dart';

/// /api/users — 관리자 전용 회원 관리.
class UsersApi {
  UsersApi(this._client);
  final ApiClient _client;

  Future<List<AppUser>> listMembers(
      {bool incompleteOnly = false,
      int? inactiveValue,
      String inactiveUnit = 'days',
      int limit = 50,
      int offset = 0}) {
    if (limit < 1 ||
        limit > 100 ||
        offset < 0 ||
        (inactiveValue != null && inactiveValue < 1) ||
        !['days', 'months'].contains(inactiveUnit)) {
      throw ArgumentError('유효하지 않은 회원 조회 조건');
    }
    return _listMembers(
        incompleteOnly, inactiveValue, inactiveUnit, limit, offset);
  }

  Future<List<AppUser>> _listMembers(bool incompleteOnly, int? inactiveValue,
      String inactiveUnit, int limit, int offset) async {
    try {
      final res = await _client.dio
          .get<dynamic>('/api/admin-members', queryParameters: {
        if (incompleteOnly) 'incompleteOnly': true,
        if (inactiveValue != null) ...{
          'inactiveValue': inactiveValue,
          'inactiveUnit': inactiveUnit
        },
        'limit': limit,
        'offset': offset,
      });
      final body = await _client.requireOk(res);
      return asListOfMaps(body['users'])
          .map(AppUser.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  Future<int> deleteMembers(List<String> emails) {
    _validateBatch(emails);
    return _deleteMembers(emails);
  }

  Future<int> clearPersonalData(List<String> emails) async {
    _validateBatch(emails);
    try {
      final res = await _client.dio.post<dynamic>('/api/admin-members', data: {
        'action': 'clear-personal-data',
        'emails': emails,
      });
      return asInt((await _client.requireOk(res))['clearedCount']);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  Future<int> _deleteMembers(List<String> emails) async {
    try {
      final res = await _client.dio
          .delete<dynamic>('/api/admin-members', data: {'emails': emails});
      return asInt((await _client.requireOk(res))['deletedCount']);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  Future<ProfileRequestResult> requestProfiles(
      {required List<String> emails, String message = ''}) {
    _validateBatch(emails);
    return _requestProfiles(emails, message);
  }

  Future<ProfileRequestResult> _requestProfiles(
      List<String> emails, String message) async {
    try {
      final res = await _client.dio.post<dynamic>('/api/admin-members', data: {
        'action': 'request-profile',
        'emails': emails,
        'message': message
      });
      final body = await _client.requireOk(res);
      return ProfileRequestResult(
          sentCount: asInt(body['sentCount']),
          pushSentCount: asInt(body['pushSentCount']),
          pushFailedCount: asInt(body['pushFailedCount']));
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  void _validateBatch(List<String> emails) {
    if (emails.isEmpty ||
        emails.length > 100 ||
        emails.any((e) => e.trim().isEmpty)) {
      throw ArgumentError('회원은 1~100명 선택해야 합니다.');
    }
  }

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
      return asListOfMaps(body['users'])
          .map(AppUser.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/users — 회원 상태 변경 (pending/approved/rejected/blocked/withdrawn)
  Future<void> updateAccess({
    required String email,
    required String status,
    String role = 'user',
    int? expectedVehicleSubmissionVersion,
    DateTime? expectedMemberCreatedAt,
  }) async {
    try {
      final res = await _client.dio.post<dynamic>(
        '/api/users',
        data: {
          'email': email,
          'status': status,
          'role': role,
          if (expectedVehicleSubmissionVersion != null)
            'expectedVehicleSubmissionVersion':
                expectedVehicleSubmissionVersion,
          if (expectedMemberCreatedAt != null)
            'expectedMemberCreatedAt':
                expectedMemberCreatedAt.toUtc().toIso8601String(),
        },
      );
      await _client.requireOk(res);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/users { action: "verify-vehicle" } — 차량 사진 승인/거절
  Future<void> verifyVehicle(
      {required String email,
      required bool approved,
      int? expectedVehicleSubmissionVersion,
      DateTime? expectedMemberCreatedAt}) async {
    try {
      final res = await _client.dio.post<dynamic>(
        '/api/users',
        data: {
          'email': email,
          'action': 'verify-vehicle',
          'approved': approved,
          if (expectedVehicleSubmissionVersion != null)
            'expectedVehicleSubmissionVersion':
                expectedVehicleSubmissionVersion,
          if (expectedMemberCreatedAt != null)
            'expectedMemberCreatedAt':
                expectedMemberCreatedAt.toUtc().toIso8601String(),
        },
      );
      await _client.requireOk(res);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}

class ProfileRequestResult {
  const ProfileRequestResult(
      {required this.sentCount,
      required this.pushSentCount,
      required this.pushFailedCount});
  final int sentCount;
  final int pushSentCount;
  final int pushFailedCount;
}
