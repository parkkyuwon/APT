import 'package:apt_ev_charging/local_test/local_api_adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isolated local fixture supports board and report lifecycle', () async {
    final dio = Dio(BaseOptions(baseUrl: LocalApiAdapter.baseUrl));
    dio.httpClientAdapter = LocalApiAdapter(admin: true);
    addTearDown(() => dio.close(force: true));
    final post =
        await dio.post('/api/board', data: {'title': '단지 이슈', 'content': '의견'});
    final id = post.data['post']['id'];
    final edited = await dio
        .put('/api/board', data: {'id': id, 'title': '변경', 'content': '의견'});
    expect(edited.data['post']['title'], '변경');
    expect((await dio.get('/api/board')).data['posts'], hasLength(1));
    await dio.delete('/api/board', queryParameters: {'id': id});
    expect((await dio.get('/api/board')).data['posts'], isEmpty);
    final report = await dio.post('/api/charger-reports',
        data: {'slotId': 'fast50-1', 'description': '고장'});
    final updated = await dio.patch('/api/charger-reports',
        data: {'id': report.data['report']['id'], 'status': 'resolved'});
    expect(updated.data['report']['status'], 'resolved');
  });
}
