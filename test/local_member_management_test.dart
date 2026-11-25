import 'package:apt_ev_charging/local_test/local_api_adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local fixture enforces admin access and selection protections',
      () async {
    final dio = Dio(BaseOptions(
        baseUrl: LocalApiAdapter.baseUrl,
        validateStatus: (status) => status != null && status < 500))
      ..httpClientAdapter = LocalApiAdapter();
    addTearDown(() => dio.close(force: true));
    expect((await dio.get('/api/admin-members')).statusCode, 403);
    dio.httpClientAdapter.close();
    dio.httpClientAdapter = LocalApiAdapter(admin: true);
    final list = await dio
        .get('/api/admin-members', queryParameters: {'incompleteOnly': true});
    expect((list.data['users'] as List).length, greaterThanOrEqualTo(2));
    final member = list.data['users'][0]['email'];
    final originalNickname = list.data['users'][0]['nickname'];
    final protected = await dio.delete('/api/admin-members', data: {
      'emails': [member, LocalApiAdapter.memberEmail]
    });
    expect(protected.statusCode, 400);
    final notice = await dio.post('/api/admin-members', data: {
      'action': 'request-profile',
      'emails': [member],
      'message': '추가 안내'
    });
    expect(notice.data['sentCount'], 1);
    expect(notice.data['pushSentCount'], 0);
    final clearing = await dio.post('/api/admin-members', data: {
      'action': 'clear-personal-data',
      'emails': [member],
    });
    expect(clearing.data['clearedCount'], 1);
    final cleaned = (await dio.get('/api/admin-members')).data['users'] as List;
    final sameMember = cleaned.firstWhere((u) => u['email'] == member) as Map;
    expect(sameMember['nickname'], originalNickname);
    expect(sameMember.containsKey('phoneNumber'), isFalse);
    expect(
        (await dio.delete('/api/admin-members', data: {
          'emails': [member]
        }))
            .data['deletedCount'],
        1);
    final remaining = await dio.get('/api/admin-members');
    expect((remaining.data['users'] as List).any((u) => u['email'] == member),
        false);
  });
}
