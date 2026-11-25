import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/community.dart';

/// Server enforces approved membership, authorship and report privacy.
class CommunityApi {
  CommunityApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? data, Map<String, dynamic>? query}) async {
    try {
      final response = await _client.dio.request<dynamic>(path,
          data: data, queryParameters: query, options: Options(method: method));
      return await _client.requireOk(response);
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  Map<String, dynamic> _item(Map<String, dynamic> body, String field) {
    final item = asMapOrNull(body[field]);
    if (item == null) throw StateError('$field missing in response');
    return item;
  }

  Future<List<BoardPost>> posts({int? before}) async {
    final body = await _request('GET', '/api/board', query: {
      'limit': 50,
      if (before != null) 'before': before,
    });
    return asListOfMaps(body['posts']).map(BoardPost.fromJson).toList();
  }

  Future<BoardPost> savePost(
      {int? id, required String title, required String content}) async {
    final body =
        await _request(id == null ? 'POST' : 'PUT', '/api/board', data: {
      if (id != null) 'id': id,
      'title': title.trim(),
      'content': content.trim(),
    });
    return BoardPost.fromJson(_item(body, 'post'));
  }

  Future<void> deletePost(int id) async {
    await _request('DELETE', '/api/board', query: {'id': id});
  }

  Future<List<ChargerReport>> reports({int? before}) async {
    final body = await _request('GET', '/api/charger-reports', query: {
      'limit': 50,
      if (before != null) 'before': before,
    });
    return asListOfMaps(body['reports']).map(ChargerReport.fromJson).toList();
  }

  Future<ChargerReport> createReport(
      {required String slotId,
      required String description,
      String? photo}) async {
    final body = await _request('POST', '/api/charger-reports', data: {
      'slotId': slotId,
      'description': description.trim(),
      if (photo != null) 'photo': photo,
    });
    return ChargerReport.fromJson(_item(body, 'report'));
  }

  Future<ChargerReport> report(int id) async {
    final body =
        await _request('GET', '/api/charger-reports', query: {'id': id});
    return ChargerReport.fromJson(_item(body, 'report'));
  }

  Future<ChargerReport> updateReportStatus(int id, String status) async {
    final body = await _request('PATCH', '/api/charger-reports', data: {
      'id': id,
      'status': status,
    });
    return ChargerReport.fromJson(_item(body, 'report'));
  }
}
