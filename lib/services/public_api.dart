import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/app_state.dart';

/// /api/public-dashboard — 비로그인 공개 대시보드 (점유 여부만).
class PublicDashboardApi {
  PublicDashboardApi(this._client);
  final ApiClient _client;

  Future<AppState> fetch() async {
    try {
      final res = await _client.dio.get<dynamic>('/api/public-dashboard');
      final body = await _client.requireOk(res);
      final stateJson = (body['state'] as Map?)?.cast<String, dynamic>() ?? const {};
      return AppState.fromJson(stateJson);
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
      final groups = (body['groups'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return HighlightResult(
        totalActive: (body['totalActive'] as num?)?.toInt() ?? 0,
        groups: groups.map(HighlightGroup.fromJson).toList(growable: false),
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
    final items = (json['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return HighlightGroup(
      typeId: (json['typeId'] as String?) ?? '',
      chargerType: (json['chargerType'] as String?) ?? '',
      badgeClass: (json['badgeClass'] as String?) ?? '',
      items: items.map(HighlightItem.fromJson).toList(growable: false),
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
        slotId: (json['slotId'] as String?) ?? '',
        slotName: (json['slotName'] as String?) ?? '',
        vehicleNumberMasked: (json['vehicleNumberMasked'] as String?) ?? '',
        startTime: (json['startTime'] as String?) ?? '',
        departureTime: (json['departureTime'] as String?) ?? '',
        chargeDuration: (json['chargeDuration'] as String?) ?? '',
      );
}
