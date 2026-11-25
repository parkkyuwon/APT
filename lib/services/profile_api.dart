import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../core/plate_recognition.dart';
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
      final profile = asMapOrNull(body['profile']);
      if (profile == null) {
        throw StateError('profile missing in response');
      }
      return AppUser.fromJson(profile);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/profile — 차량번호와 번호판 사진/OCR 후보 제출.
  Future<AppUser> updateProfile({
    required String nickname,
    required String vehicleNumber,
    String? vehiclePhotoBase64,
    List<String>? ocrCandidates,
    String? googleCredential,
  }) async {
    if (nickname.trim().isEmpty || nickname.trim().length > 30) {
      throw ArgumentError('닉네임을 1~30자로 입력해 주세요.');
    }
    if (!isSinglePlate(vehicleNumber)) {
      throw ArgumentError('차량번호 한 개만 정확히 입력해 주세요.');
    }
    try {
      final payload = <String, dynamic>{
        'nickname': nickname.trim(),
        'vehicleNumber': vehicleNumber,
        if (ocrCandidates != null) 'ocrCandidates': ocrCandidates,
        if (vehiclePhotoBase64 != null) 'vehiclePhoto': vehiclePhotoBase64,
        if (googleCredential != null) 'googleCredential': googleCredential,
      };
      final res =
          await _client.dio.post<dynamic>('/api/profile', data: payload);
      final body = await _client.requireOk(res);
      final profile = asMapOrNull(body['profile']);
      if (profile == null) {
        throw StateError('profile missing in response');
      }
      return AppUser.fromJson(profile);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/profile { action: "consent", version } — 개인정보 동의 저장
  Future<void> recordConsent({String version = '1.3'}) async {
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
