import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/api_client.dart';
import '../core/errors.dart';
import '../core/state_cache.dart';
import '../models/app_state.dart';
import '../models/parking_slot.dart';
import '../services/services.dart';
import 'connectivity_provider.dart';

/// 전역 주차 현황 상태. 30초 폴링 + 영속 캐시 + 낙관적 업데이트 지원.
/// 앱 백그라운드 시 폴링 중지, 포그라운드 복귀 시 즉시 1회 + 30초 주기 재개.
class AppStateProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppStateProvider(this._services, {ConnectivityProvider? connectivity})
      : _connectivity = connectivity {
    WidgetsBinding.instance.addObserver(this);
  }

  final ApiServices _services;
  final ConnectivityProvider? _connectivity;

  AppState _state = AppState.empty();
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdated;
  Timer? _pollTimer;
  bool _started = false;
  bool _guestMode = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _lifecycle == AppLifecycleState.resumed;
    _lifecycle = state;
    if (state == AppLifecycleState.resumed && !wasResumed && _started) {
      // 포그라운드 복귀 — 즉시 갱신 + 폴링 재가동
      _startPollTimer();
      refresh();
    } else if (state != AppLifecycleState.resumed && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  AppState get state => _state;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;
  bool get isGuestMode => _guestMode;

  /// approved 전환 시 호출. 캐시된 상태가 있으면 즉시 노출하고,
  /// 백그라운드로 최신 상태를 받아 동기화한다.
  Future<void> start() async {
    if (_guestMode) {
      // 게스트에서 회원으로 전환 — 게스트 상태를 초기화하고 회원 흐름으로 재시작
      _guestMode = false;
      _started = false;
      _pollTimer?.cancel();
      _pollTimer = null;
    }
    if (!_started) {
      _started = true;
      final cached = StateCache.load();
      if (cached != null) {
        _state = cached;
        _lastUpdated = StateCache.cachedAt();
        notifyListeners();
      }
    }
    await refresh();
    _startPollTimer();
  }

  /// 게스트 진입 시 호출. /api/public-dashboard 에서 점유 여부만 받는다.
  /// 영속 캐시는 사용하지 않는다(회원 PII 캐시와 분리).
  Future<void> startGuest() async {
    _guestMode = true;
    _started = true;
    await refresh();
    _startPollTimer();
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _state = _guestMode
          ? await _services.publicDashboard.fetch()
          : await _services.state.fetch();
      _lastUpdated = DateTime.now();
      // 비동기 캐시 저장 — UI 블록하지 않음.
      if (!_guestMode) unawaited(StateCache.save(_state));
      _connectivity?.markOnline();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _connectivity?.markOnline(); // 서버는 응답함 (4xx) → 네트워크는 OK
    } on NetworkException catch (e) {
      _errorMessage = e.message;
      _connectivity?.markOffline();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 서버 권위 응답으로 상태 교체. 호출자는 payload 를 빌드해서 전달.
  Future<AppState> _saveServerAuthoritative(Map<String, dynamic> payload) async {
    final next = await _services.state.save(payload);
    _state = next;
    _lastUpdated = DateTime.now();
    unawaited(StateCache.save(_state));
    return next;
  }

  /// 관리자 전체 상태 일괄 저장 — 지도 편집기 등에서 사용.
  Future<void> saveFullState(Map<String, dynamic> payload) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _saveServerAuthoritative(payload);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 단일 슬롯 SlotDetail 변경.
  ///
  /// 낙관적 업데이트: 즉시 로컬 _state 갱신 후 notifyListeners — UI 즉시 반영.
  /// 서버 호출 실패 시 이전 상태로 롤백. 호출부가 throw 처리하여 SnackBar 표시.
  Future<void> upsertSlotDetail({
    required String slotId,
    required SlotDetail detail,
  }) async {
    final snapshot = _state;
    final nextDetails = Map<String, SlotDetail>.from(snapshot.slotDetails);
    nextDetails[slotId] = detail;
    _state = _withSlotDetails(snapshot, nextDetails);
    notifyListeners();

    final payload = _stateToPayload(snapshot);
    final detailsJson =
        Map<String, dynamic>.from(payload['slotDetails'] as Map? ?? {});
    detailsJson[slotId] = detail.toJson();
    payload['slotDetails'] = detailsJson;

    try {
      await _saveServerAuthoritative(payload);
      notifyListeners();
    } catch (e) {
      _state = snapshot;
      notifyListeners();
      rethrow;
    }
  }

  /// 주차 해제 (출차).
  Future<void> clearSlotDetail(String slotId) async {
    final snapshot = _state;
    final nextDetails = Map<String, SlotDetail>.from(snapshot.slotDetails);
    nextDetails.remove(slotId);
    _state = _withSlotDetails(snapshot, nextDetails);
    notifyListeners();

    final payload = _stateToPayload(snapshot);
    final detailsJson =
        Map<String, dynamic>.from(payload['slotDetails'] as Map? ?? {});
    detailsJson.remove(slotId);
    payload['slotDetails'] = detailsJson;

    try {
      await _saveServerAuthoritative(payload);
      notifyListeners();
    } catch (e) {
      _state = snapshot;
      notifyListeners();
      rethrow;
    }
  }

  /// 관리자 전용 — 주차 불가/가능 토글.
  Future<void> toggleSlotBlocked(String slotId) async {
    final current = _state.slotDetails[slotId] ?? const SlotDetail();
    final toggled = current.copyWith(parkingBlocked: !current.parkingBlocked);
    await upsertSlotDetail(slotId: slotId, detail: toggled);
  }

  /// 내 소유 슬롯 id (없으면 null).
  String? findMyOwnedSlot(String email) {
    for (final entry in _state.slotDetails.entries) {
      if (entry.value.ownerEmail == email) return entry.key;
    }
    return null;
  }

  /// 다음 GET /api/state 가 If-None-Match 없이 200 으로 받도록 ETag 캐시 무효화.
  /// 강제 새로고침 시(딥링크 자동 등록 등) 호출.
  void invalidateStateCache() {
    ApiClient.instance.etagCache.invalidate('/api/state');
  }

  /// 캐시/로그아웃 시 호출 — 메모리 + 영속 캐시 모두 초기화.
  Future<void> reset() async {
    stop();
    _state = AppState.empty();
    _lastUpdated = null;
    _errorMessage = null;
    _isLoading = false;
    _started = false;
    _guestMode = false;
    await StateCache.clear();
    notifyListeners();
  }

  AppState _withSlotDetails(AppState s, Map<String, SlotDetail> details) {
    return AppState(
      adEnabled: s.adEnabled,
      maintenanceMode: s.maintenanceMode,
      chatRetentionDays: s.chatRetentionDays,
      popupNotice: s.popupNotice,
      counts: s.counts,
      slots: s.slots,
      slotNames: s.slotNames,
      slotDetails: details,
      slotImages: s.slotImages,
      slotMapPositions: s.slotMapPositions,
      beaconMappings: s.beaconMappings,
      beaconPositions: s.beaconPositions,
    );
  }

  AppState _withBeaconPositions(
      AppState s, Map<String, BeaconPosition> positions) {
    return AppState(
      adEnabled: s.adEnabled,
      maintenanceMode: s.maintenanceMode,
      chatRetentionDays: s.chatRetentionDays,
      popupNotice: s.popupNotice,
      counts: s.counts,
      slots: s.slots,
      slotNames: s.slotNames,
      slotDetails: s.slotDetails,
      slotImages: s.slotImages,
      slotMapPositions: s.slotMapPositions,
      beaconMappings: s.beaconMappings,
      beaconPositions: positions,
    );
  }

  /// 비콘 → 지도 위치 저장. position 이 null 이면 매핑 제거.
  Future<void> upsertBeaconPosition({
    required String beaconId,
    required BeaconPosition? position,
  }) async {
    final snapshot = _state;
    final next = Map<String, BeaconPosition>.from(snapshot.beaconPositions);
    if (position == null) {
      next.remove(beaconId);
    } else {
      next[beaconId] = position;
    }
    _state = _withBeaconPositions(snapshot, next);
    notifyListeners();

    final payload = _stateToPayload(_state);
    try {
      await _saveServerAuthoritative(payload);
      notifyListeners();
    } catch (e) {
      _state = snapshot;
      notifyListeners();
      rethrow;
    }
  }

  /// 비콘 → 슬롯 매핑 저장. 비콘 ID(MAC) 가 비어 있으면 매핑 제거.
  Future<void> upsertBeaconMapping({
    required String beaconId,
    required String slotId,
  }) async {
    final snapshot = _state;
    final next = Map<String, String>.from(snapshot.beaconMappings);
    if (slotId.isEmpty) {
      next.remove(beaconId);
    } else {
      next[beaconId] = slotId;
    }
    _state = AppState(
      adEnabled: snapshot.adEnabled,
      maintenanceMode: snapshot.maintenanceMode,
      chatRetentionDays: snapshot.chatRetentionDays,
      popupNotice: snapshot.popupNotice,
      counts: snapshot.counts,
      slots: snapshot.slots,
      slotNames: snapshot.slotNames,
      slotDetails: snapshot.slotDetails,
      slotImages: snapshot.slotImages,
      slotMapPositions: snapshot.slotMapPositions,
      beaconMappings: next,
    );
    notifyListeners();

    final payload = _stateToPayload(_state);
    try {
      await _saveServerAuthoritative(payload);
      notifyListeners();
    } catch (e) {
      _state = snapshot;
      notifyListeners();
      rethrow;
    }
  }

  Map<String, dynamic> _stateToPayload(AppState s) {
    final slotDetails = <String, dynamic>{};
    s.slotDetails.forEach((id, d) => slotDetails[id] = d.toJson());

    final slots = <String, dynamic>{};
    s.slots.forEach((typeId, list) {
      slots[typeId] = list.map((sl) => sl.toJson()).toList();
    });

    return <String, dynamic>{
      'adEnabled': s.adEnabled,
      'maintenanceMode': s.maintenanceMode,
      'chatRetentionDays': s.chatRetentionDays,
      'popupNotice': <String, dynamic>{
        'enabled': s.popupNotice.enabled,
        'content': s.popupNotice.content,
        'autoCloseSeconds': s.popupNotice.autoCloseSeconds,
      },
      'counts': s.counts,
      'slots': slots,
      'slotNames': s.slotNames,
      'slotImages': s.slotImages,
      'slotDetails': slotDetails,
      'slotMapPositions':
          s.slotMapPositions.map((k, v) => MapEntry(k, v.toJson())),
      'beaconMappings': s.beaconMappings,
      'beaconPositions':
          s.beaconPositions.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop();
    super.dispose();
  }
}
