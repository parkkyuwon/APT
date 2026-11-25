import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/errors.dart';
import '../models/indoor_positioning.dart';
import '../models/app_state.dart';
import '../models/published_indoor_dataset.dart';
import '../services/indoor_positioning_api.dart';
import '../services/indoor_survey_store.dart';

/// Server publication and its account/environment scoped offline snapshot.
/// Private survey sessions are never used as a substitute for this publication.
class IndoorDatasetProvider extends ChangeNotifier {
  IndoorDatasetProvider(this.api,
      {required this.cacheScope, IndoorSurveyStore? store})
      : store = store ?? IndoorSurveyStore(),
        _ownsStore = store == null {
    if (cacheScope.isEmpty) throw ArgumentError('A cache scope is required.');
  }
  final IndoorPositioningApi api;
  final String cacheScope;
  final IndoorSurveyStore store;
  final bool _ownsStore;
  PublishedIndoorDataset? _dataset;
  PublishedIndoorDataset? get dataset => _dataset;
  bool get available => !revoked && (_dataset?.usable ?? false);
  bool loading = false, offline = false, revoked = false;
  String? error;
  bool _disposed = false, _cacheLoaded = false, _publishing = false;
  int _generation = 0;
  bool _current(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed || _publishing) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      if (!_cacheLoaded && !revoked) {
        try {
          final cached = await store.loadPublished(cacheScope);
          if (!_current(generation)) return;
          _cacheLoaded = true;
          if (cached != null) {
            _dataset = PublishedIndoorDataset.fromJson(cached);
            offline = true;
            _notify();
          }
        } catch (_) {
          if (!_current(generation)) return;
          _cacheLoaded = true;
          error = '저장된 공용 실내 자료를 읽지 못했습니다.';
        }
      }
      if (!_current(generation)) return;
      final remote = await api.fetch();
      if (!_current(generation)) return;
      await _activate(remote, generation);
    } catch (e) {
      if (_current(generation)) await _handleFailure(e, generation);
    } finally {
      if (_current(generation)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> publish(
      {required bool enabled,
      required List<SurveySession> surveys,
      Map<String, BeaconPosition>? beaconPositions}) async {
    if (_disposed || loading) return false;
    final known = _dataset;
    if (known == null || revoked) {
      error = '최신 공용 자료를 먼저 불러온 후 다시 시도해 주세요.';
      _notify();
      return false;
    }
    final generation = ++_generation;
    _publishing = true;
    loading = true;
    error = null;
    _notify();
    try {
      final remote = await api.publish(
          expectedRevision: known.revision,
          enabled: enabled,
          surveys: surveys,
          beaconPositions: beaconPositions ?? known.beaconPositions);
      if (!_current(generation)) return false;
      await _activate(remote, generation);
      return _current(generation);
    } catch (e) {
      if (_current(generation)) await _handleFailure(e, generation);
      return false;
    } finally {
      _publishing = false;
      if (_current(generation)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _activate(PublishedIndoorDataset remote, int generation) async {
    final validated = PublishedIndoorDataset.fromJson(remote.toJson());
    if (validated.revision < (_dataset?.revision ?? 0)) {
      throw const FormatException('Shared indoor revision regressed.');
    }
    // A server disable is effective immediately, including when local storage
    // cannot persist it. Enabled replacements activate after a successful save.
    if (!validated.enabled) {
      _dataset = validated;
      revoked = false;
      offline = false;
      _notify();
    }
    await store.savePublished(cacheScope, validated.toJson());
    if (!_current(generation)) return;
    _dataset = validated;
    _cacheLoaded = true;
    revoked = false;
    offline = false;
    error = null;
  }

  Future<void> _handleFailure(Object failure, int generation) async {
    if (failure is ApiException &&
        (failure.statusCode == 401 || failure.statusCode == 403)) {
      _dataset = null;
      revoked = true;
      offline = false;
      error = '공용 실내 자료 접근 권한을 확인해 주세요.';
      _notify();
      try {
        await store.deletePublished(cacheScope);
      } catch (_) {
        if (_current(generation)) {
          error = '접근 권한이 해제되었습니다. 저장된 자료 삭제를 다시 시도해 주세요.';
        }
      }
      return;
    }
    offline = _dataset != null;
    error = failure is ApiException && failure.statusCode == 409
        ? '다른 관리자가 공용 자료를 변경했습니다. 새로고침 후 다시 시도해 주세요.'
        : failure is FormatException
            ? '공용 자료의 형식 또는 버전이 올바르지 않습니다. 저장된 자료를 유지합니다.'
            : '최신 공용 자료를 처리하지 못했습니다. 저장된 자료가 있으면 계속 사용합니다.';
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    if (_ownsStore) unawaited(store.close());
    super.dispose();
  }
}
