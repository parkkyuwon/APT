import 'dart:math';

import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/parking_slot.dart';

/// Voice signaling uses the same authenticated session as parking state.
class ParkingVoiceApi {
  ParkingVoiceApi(this._client);
  final ApiClient _client;

  String _messageId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Map<String, dynamic>> _get(Map<String, dynamic> query) async {
    try {
      final response = await _client.dio.get<dynamic>('/api/parking-voice',
          queryParameters: query,
          options: Options(headers: {'Cache-Control': 'no-store'}));
      return await _client.requireOk(response);
    } on DioException catch (error) {
      _client.rethrowAsApp(error);
    }
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> data) async {
    try {
      final response =
          await _client.dio.post<dynamic>('/api/parking-voice', data: data);
      return await _client.requireOk(response);
    } on DioException catch (error) {
      _client.rethrowAsApp(error);
    }
  }

  Map<String, dynamic> _parking(String slotId, SlotDetail detail) => {
        'slotId': slotId,
        'expectedParkingRegistrationId': detail.parkingRegistrationId,
        'expectedStartTime': detail.startTime,
      };

  Map<String, dynamic> _call(Map<String, dynamic> body) {
    final call = asMapOrNull(body['call']);
    if (call == null) throw StateError('통화 상태 응답이 없습니다.');
    return call;
  }

  Future<Map<String, dynamic>> fetchCapability() =>
      _get({'action': 'capability'});

  Future<Map<String, dynamic>> setAvailability({
    required String slotId,
    required SlotDetail detail,
    required bool callAllowed,
  }) =>
      _post({
        'action': 'set-availability',
        ..._parking(slotId, detail),
        'callAllowed': callAllowed,
      });

  Future<SlotDetail> setReceiving(
      String slotId, SlotDetail detail, bool allowed) async {
    final body = await setAvailability(
        slotId: slotId, detail: detail, callAllowed: allowed);
    final result = asMapOrNull(body['detail']);
    if (result == null) throw StateError('수신 설정 응답이 없습니다.');
    return SlotDetail.fromJson(result);
  }

  Future<Map<String, dynamic>> create(String slotId, SlotDetail detail) async =>
      _call(await _post({
        'action': 'create',
        ..._parking(slotId, detail),
        'requestKey': _messageId(),
      }));

  Future<List<Map<String, dynamic>>> inbox() async =>
      asListOfMaps((await _get({'action': 'inbox'}))['calls']);

  Future<Map<String, dynamic>> poll(String id, int afterSequence) => _get({
        'action': 'poll',
        'id': id,
        'afterSequence': afterSequence,
      });

  Future<Map<String, dynamic>> action(String id, String action) async =>
      _call(await _post({'action': action, 'id': id}));

  Future<void> signal(
      String id, String type, Map<String, dynamic> payload) async {
    await _post({
      'action': 'signal',
      'id': id,
      'clientMessageId': _messageId(),
      'type': type,
      'payload': payload,
    });
  }

  Future<Map<String, dynamic>> ice(String id) =>
      _get({'action': 'ice', 'id': id});
}
