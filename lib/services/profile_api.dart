import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/user.dart';

/// /api/profile — 프로필 조회/수정/동의/탈퇴.
class ProfileApi {
  ProfileApi(this._client);
  final ApiClient _client;

  /// GET /api/profile — 본인 프로필
  Future<AppUser> fetchMyProfile() async {
    try {
      final res = await _client.dio.get<dynamic>('/api/profile');
      final body = await _client.requireOk(res);
      final profile = (body['profile'] as Map?)?.cast<String, dynamic>();
      if (profile == null) {
        throw StateError('profile missing in response');
      }
      return AppUser.fromJson(profile);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/profile — 닉네임/차량번호/전화번호(+선택 차량사진) 수정
  Future<AppUser> updateProfile({
    required String nickname,
    required String vehicleNumber,
    required String phoneNumber,
    String? vehiclePhotoBase64,
    String? googleCredential,
  }) async {
    try {
      final payload = <String, dynamic>{
        'nickname': nickname,
        'vehicleNumber': vehicleNumber,
        'phoneNumber': phoneNumber,
        if (vehiclePhotoBase64 != null) 'vehiclePhoto': vehiclePhotoBase64,
        if (googleCredential != null) 'googleCredential': googleCredential,
      };
      final res = await _client.dio.post<dynamic>('/api/profile', data: payload);
      final body = await _client.requireOk(res);
      final profile = (body['profile'] as Map?)?.cast<String, dynamic>();
      if (profile == null) {
        throw StateError('profile missing in response');
      }
      return AppUser.fromJson(profile);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/profile { action: "consent", version } — 개인정보 동의 저장
  Future<void> recordConsent({String version = '1.0'}) async {
    try {
      final res = await _client.dio.post<dynamic>(
        '/api/profile',
        data: {'action': 'consent', 'version': version},
      );
      await _client.requireOk(res);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// DELETE /api/profile — 계정 탈퇴 (7일 유예 후 완전 삭제)
  Future<void> withdraw() async {
    try {
      final res = await _client.dio.delete<dynamic>('/api/profile');
      await _client.requireOk(res);
      await _client.clearSession();
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}
