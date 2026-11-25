import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/indoor_positioning.dart';
import '../models/app_state.dart';
import '../models/published_indoor_dataset.dart';

class IndoorPositioningApi {
  IndoorPositioningApi(this._client);
  final ApiClient _client;
  Future<PublishedIndoorDataset> fetch() async {
    try {
      final response =
          await _client.dio.get<dynamic>('/api/indoor-positioning');
      final body = await _client.requireOk(response);
      return PublishedIndoorDataset.fromJson(
          Map<String, dynamic>.from(body['dataset'] as Map));
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }

  Future<PublishedIndoorDataset> publish(
      {required int expectedRevision,
      required bool enabled,
      required List<SurveySession> surveys,
      Map<String, BeaconPosition>? beaconPositions}) async {
    final records = surveys
        .where((s) => s.usable)
        .map((s) => {
              ...s.toJson(),
              'accountScope': 'published',
              'label': '',
              'deviceGroup': 'local',
            })
        .toList();
    try {
      _client.etagCache.invalidate('/api/indoor-positioning');
      final response =
          await _client.dio.put<dynamic>('/api/indoor-positioning', data: {
        'expectedRevision': expectedRevision,
        'enabled': enabled,
        'siteId': 'home',
        'mapVersion': 'simplified-v1',
        'surveys': records,
        'beaconPositions': (beaconPositions ?? <String, BeaconPosition>{})
            .map((id, position) => MapEntry(id, position.toJson())),
      });
      final body = await _client.requireOk(response);
      return PublishedIndoorDataset.fromJson(
          Map<String, dynamic>.from(body['dataset'] as Map));
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}
