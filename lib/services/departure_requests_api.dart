import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/departure_request.dart';
import '../models/parking_slot.dart';

class DepartureRequestsApi {
  DepartureRequestsApi(this._client);
  final ApiClient _client;

  Future<DepartureRequest> send(
      {required String slotId, required SlotDetail detail}) async {
    try {
      final res =
          await _client.dio.post<dynamic>('/api/departure-requests', data: {
        'slotId': slotId,
        if (detail.ownerEmail.isNotEmpty)
          'expectedOwnerEmail': detail.ownerEmail,
        'expectedStartTime': detail.startTime,
      });
      return _request(await _client.requireOk(res));
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  Future<List<DepartureRequest>> list({int? beforeId}) async {
    try {
      final res = await _client.dio
          .get<dynamic>('/api/departure-requests', queryParameters: {
        'limit': 30,
        if (beforeId != null) 'before': beforeId,
      });
      final body = await _client.requireOk(res);
      return asListOfMaps(body['requests'])
          .map(DepartureRequest.fromJson)
          .toList();
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  Future<DepartureRequest> markRead(int id) async {
    try {
      final res = await _client.dio
          .patch<dynamic>('/api/departure-requests', data: {'id': '$id'});
      return _request(await _client.requireOk(res));
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  Future<DepartureRequest> get(int id) async {
    try {
      final res = await _client.dio
          .get<dynamic>('/api/departure-requests', queryParameters: {'id': id});
      return _request(await _client.requireOk(res));
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  DepartureRequest _request(Map<String, dynamic> body) {
    final json = asMapOrNull(body['request']);
    if (json == null) throw StateError('출차 요청 응답이 없습니다.');
    return DepartureRequest.fromJson(
        {...json, 'retryAfterSeconds': body['retryAfterSeconds']});
  }

  Future<void> registerToken(String token, String platform) async {
    try {
      final res = await _client.dio.post<dynamic>('/api/push-tokens',
          data: {'token': token, 'platform': platform});
      await _client.requireOk(res);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  Future<void> removeToken(String token) async {
    try {
      final res = await _client.dio
          .delete<dynamic>('/api/push-tokens', data: {'token': token});
      await _client.requireOk(res);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}
