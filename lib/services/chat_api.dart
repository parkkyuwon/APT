import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/chat_message.dart';

/// /api/chat — approved 세션 전용 채팅.
class ChatApi {
  ChatApi(this._client);
  final ApiClient _client;

  /// GET /api/chat?limit=30&after=<id>
  Future<List<ChatMessage>> list({int limit = 30, int? afterId}) async {
    try {
      final res = await _client.dio.get<dynamic>(
        '/api/chat',
        queryParameters: {
          'limit': limit,
          if (afterId != null && afterId > 0) 'after': afterId,
        },
      );
      final body = await _client.requireOk(res);
      final list = (body['messages'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return list.map(ChatMessage.fromJson).toList(growable: false);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// POST /api/chat { message }
  Future<ChatMessage> send(String message) async {
    try {
      final res = await _client.dio.post<dynamic>(
        '/api/chat',
        data: {'message': message},
      );
      final body = await _client.requireOk(res);
      final m = (body['message'] as Map?)?.cast<String, dynamic>();
      if (m == null) throw StateError('chat message missing in response');
      return ChatMessage.fromJson(m);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// PUT /api/chat?id=<id> { message }
  Future<ChatMessage> edit({required int id, required String message}) async {
    try {
      final res = await _client.dio.put<dynamic>(
        '/api/chat',
        queryParameters: {'id': id},
        data: {'message': message},
      );
      final body = await _client.requireOk(res);
      final m = (body['message'] as Map?)?.cast<String, dynamic>();
      if (m == null) throw StateError('chat message missing in response');
      return ChatMessage.fromJson(m);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  /// DELETE /api/chat?id=<id>
  Future<void> delete(int id) async {
    try {
      final res = await _client.dio.delete<dynamic>(
        '/api/chat',
        queryParameters: {'id': id},
      );
      await _client.requireOk(res);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}
