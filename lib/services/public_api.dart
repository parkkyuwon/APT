import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/app_state.dart';

/// /api/public-dashboard — 비로그인 공개 대시보드 (점유 여부만).
class PublicDashboardApi {
  PublicDashboardApi(this._client);
  final ApiClient _client;

  Future<AppState> fetch() async {
    try {
      final res = await _client.dio.get<dynamic>('/api/public-dashboard');
      final body = await _client.requireOk(res);
      return AppState.fromJson(asMapOrNull(body['state']) ?? const {});
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}

/// /api/public-highlight — 최근 점유 하이라이트 (비로그인).
class PublicHighlightApi {
  PublicHighlightApi(this._client);
  final ApiClient _client;

  Future<HighlightResult> fetch() async {
    try {
      final res = await _client.dio.get<dynamic>('/api/public-highlight');
      final body = await _client.requireOk(res);
      return HighlightResult(
        totalActive: asInt(body['totalActive']),
        groups: asListOfMaps(body['groups'])
            .map(HighlightGroup.fromJson)
            .toList(growable: false),
      );
    } on DioException catch (e) {
      _client.rethrowAsApp(e);
    }
  }
}

class HighlightResult {
  HighlightResult({required this.totalActive, required this.groups});
  final int totalActive;
  final List<HighlightGroup> groups;
}

class HighlightGroup {
  HighlightGroup({
    required this.typeId,
    required this.chargerType,
    required this.badgeClass,
    required this.items,
  });

  final String typeId;
  final String chargerType;
  final String badgeClass;
  final List<HighlightItem> items;

  factory HighlightGroup.fromJson(Map<String, dynamic> json) {
    return HighlightGroup(
      typeId: asStr(json['typeId']),
      chargerType: asStr(json['chargerType']),
      badgeClass: asStr(json['badgeClass']),
      items: asListOfMaps(json['items'])
          .map(HighlightItem.fromJson)
          .toList(growable: false),
    );
  }
}

class HighlightItem {
  HighlightItem({
    required this.slotId,
    required this.slotName,
    required this.vehicleNumberMasked,
    required this.startTime,
    required this.departureTime,
    required this.chargeDuration,
  });

  final String slotId;
  final String slotName;
  final String vehicleNumberMasked;
  final String startTime;
  final String departureTime;
  final String chargeDuration;

  factory HighlightItem.fromJson(Map<String, dynamic> json) => HighlightItem(
        slotId: asStr(json['slotId']),
        slotName: asStr(json['slotName']),
        vehicleNumberMasked: asStr(json['vehicleNumberMasked']),
        startTime: asStr(json['startTime']),
        departureTime: asStr(json['departureTime']),
        chargeDuration: asStr(json['chargeDuration']),
      );
}
