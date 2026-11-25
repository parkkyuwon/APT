import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/member_notice.dart';

class MemberNoticesApi {
  MemberNoticesApi(this._client);
  final ApiClient _client;

  Future<List<MemberNotice>> list() async {
    try {
      final response = await _client.dio.get<dynamic>('/api/member-notices');
      final body = await _client.requireOk(response);
      return asListOfMaps(body['notices'])
          .map(MemberNotice.fromJson)
          .where((notice) => notice.message.trim().isNotEmpty)
          .toList();
    } on DioException catch (error) {
      _client.rethrowAsApp(error);
    }
  }
}
