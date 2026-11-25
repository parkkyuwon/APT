import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/api_client.dart';
import '../core/errors.dart';
import '../core/state_cache.dart';
import '../models/app_state.dart';
import '../models/parking_slot.dart';
import '../services/services.dart';
import 'connectivity_provider.dart';
import 'auth_provider.dart';

/// 전역 주차 현황 상태. 30초 폴링 + 영속 캐시 + 낙관적 업데이트 지원.
/// 앱 백그라운드 시 폴링 중지, 포그라운드 복귀 시 즉시 1회 + 30초 주기 재개.
class AppStateProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppStateProvider(this._services,
      {ConnectivityProvider? connectivity, AuthProvider? auth})
      : _connectivity = connectivity,
        _auth = auth {
    WidgetsBinding.instance.addObserver(this);
    _scope = _authScope;
    _auth?.addListener(_onAuthChanged);
  }

  final ApiServices _services;
  final ConnectivityProvider? _connectivity;
  final AuthProvider? _auth;
  String? _scope;
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _refreshFuture;
  Future<void> _writeQueue = Future<void>.value();
  int _pendingWrites = 0;
  int _revision = 0;
  int _readSequence = 0;

  Future<void> _queueWrite(Future<void> Function() operation) {
    _ensureWritable();
    final generation = _generation;
    _revision++;
    _readSequence++;
    _refreshFuture = null;
    _isLoading = false;
    _pendingWrites++;
    final result = _writeQueue.then((_) async {
      if (!_isCurrent(generation)) throw StateError('회원 세션이 변경되었습니다.');
      try {
        await operation();
      } on ApiException catch (error) {
        _auth?.handleApiError(error);
        rethrow;
      }
    }).whenComplete(() {
      if (_isCurrent(generation)) _pendingWrites--;
    });
    _writeQueue =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  String? get _authScope {
    final auth = _auth;
    if (auth == null) return null;
    if (auth.stage == AuthStage.guest) return 'guest';
    if (auth.stage == AuthStage.approved || auth.stage == AuthStage.admin) {
      if (auth.session == null || auth.session!.email.isEmpty) return null;
      return 'member:${auth.session?.email}';
    }
    return null;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _onAuthChanged() {
    final next = _authScope;
    if (next == _scope) return;
    final previous = _scope;
    _scope = next;
    _clearMemory();
    ApiClient.instance.invalidatePendingResponses();
    // 첫 세션 복원은 소유자가 맞는 캐시를 유지한다.
    if (previous != null || next == null) unawaited(StateCache.clear());
    notifyListeners();
  }

  void _clearMemory() {
    _generation++;
    _revision++;
    _pendingWrites = 0;
    _writeQueue = Future<void>.value();
    stop();
    _refreshFuture = null;
    _state = AppState.empty();
    _lastUpdated = null;
    _errorMessage = null;
    _isLoading = false;
    _started = false;
    _guestMode = false;
  }

  void _ensureWritable() {
    if (_disposed ||
        _guestMode ||
        (_auth != null && !(_scope?.startsWith('member:') ?? false))) {
      throw StateError('회원 세션에서만 주차 정보를 변경할 수 있습니다.');
    }
  }

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
    if (!_started || _disposed || _lifecycle != AppLifecycleState.resumed) {
      return;
    }
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
    if (_disposed) return;
    if (_auth != null && !(_scope?.startsWith('member:') ?? false)) return;
    if (_guestMode) {
      // 게스트에서 회원으로 전환 — 게스트 상태를 초기화하고 회원 흐름으로 재시작
      _clearMemory();
    }
    if (!_started) {
      _started = true;
      final cached = StateCache.load(owner: _auth?.session?.email);
      if (cached != null) {
        _state = cached;
        _lastUpdated = StateCache.cachedAt();
        notifyListeners();
      }
    }
    final generation = _generation;
    await refresh();
    if (_isCurrent(generation)) _startPollTimer();
  }

  /// 게스트 진입 시 호출. /api/public-dashboard 에서 점유 여부만 받는다.
  /// 영속 캐시는 사용하지 않는다(회원 PII 캐시와 분리).
  Future<void> startGuest() async {
    if (_disposed || (_auth != null && _scope != 'guest')) return;
    if (!_guestMode) {
      _clearMemory();
      unawaited(StateCache.clear());
    }
    _guestMode = true;
    _started = true;
    final generation = _generation;
    notifyListeners();
    await refresh();
    if (_isCurrent(generation)) _startPollTimer();
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _started = false;
  }

  Future<void> refresh() {
    if (_disposed || (_auth != null && _scope == null)) {
      return Future<void>.value();
    }
    if (_pendingWrites > 0) return _writeQueue.then((_) => refresh());
    return _refreshFuture ??= _refresh(_generation, _guestMode);
  }

  Future<void> _refresh(int generation, bool guestMode) async {
    final revision = _revision;
    final sequence = ++_readSequence;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final next = guestMode
          ? await _services.publicDashboard.fetch()
          : await _services.state.fetch();
      if (!_isCurrent(generation) || revision != _revision) return;
      _state = next;
      _lastUpdated = DateTime.now();
      // 비동기 캐시 저장 — UI 블록하지 않음.
      if (!guestMode) {
        unawaited(StateCache.save(_state, owner: _auth?.session?.email));
      }
      _connectivity?.markOnline();
    } on ApiException catch (e) {
      if (!_isCurrent(generation)) return;
      _auth?.handleApiError(e);
      if (!_isCurrent(generation) || revision != _revision) return;
      _errorMessage = e.message;
      _connectivity?.markOnline(); // 서버는 응답함 (4xx) → 네트워크는 OK
    } on NetworkException catch (e) {
      if (!_isCurrent(generation) || revision != _revision) return;
      _errorMessage = e.message;
      _connectivity?.markOffline();
    } finally {
      if (_isCurrent(generation) && sequence == _readSequence) {
        _refreshFuture = null;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 서버 권위 응답으로 상태 교체. 호출자는 payload 를 빌드해서 전달.
  Future<AppState> _saveServerAuthoritative(
      Map<String, dynamic> payload) async {
    _ensureWritable();
    final generation = _generation;
    final next = await _services.state.save(payload);
    if (!_isCurrent(generation)) return next;
    _state = next;
    _lastUpdated = DateTime.now();
    unawaited(StateCache.save(_state, owner: _auth?.session?.email));
    return next;
  }

  /// 관리자 전체 상태 일괄 저장 — 지도 편집기 등에서 사용.
  Future<void> saveFullState(Map<String, dynamic> payload) {
    // Capture the version with the caller's snapshot, before waiting in queue.
    final versioned = {
      ...payload,
      'stateVersion': payload['stateVersion'] ?? _state.stateVersion,
    };
    return _queueWrite(() => _saveFullState(versioned));
  }

  Future<void> _saveFullState(Map<String, dynamic> payload) async {
    _ensureWritable();
    final generation = _generation;
    _isLoading = true;
    notifyListeners();
    try {
      await _saveServerAuthoritative(payload);
    } finally {
      if (_isCurrent(generation)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 단일 슬롯 SlotDetail 변경.
  ///
  /// 낙관적 업데이트: 즉시 로컬 _state 갱신 후 notifyListeners — UI 즉시 반영.
  /// 서버 호출 실패 시 이전 상태로 롤백. 호출부가 throw 처리하여 SnackBar 표시.
  Future<void> upsertSlotDetail({
    required String slotId,
    required SlotDetail detail,
    bool? callAllowed,
  }) =>
      _queueWrite(() => _upsertSlotDetail(
          slotId: slotId, detail: detail, callAllowed: callAllowed));

  Future<void> _upsertSlotDetail({
    required String slotId,
    required SlotDetail detail,
    bool? callAllowed,
  }) async {
    _ensureWritable();
    final generation = _generation;
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
      if (_isCurrent(generation)) notifyListeners();
    } catch (e) {
      if (_isCurrent(generation)) {
        _state = snapshot;
        notifyListeners();
      }
      rethrow;
    }
    if (callAllowed != null && _isCurrent(generation)) {
      final current = _state.slotDetails[slotId];
      if (current != null && current.callAllowed != callAllowed) {
        try {
          await _setParkingCallAllowed(slotId, callAllowed);
        } catch (e) {
          throw StateError('주차는 저장되었지만 앱 음성통화 수신 설정을 변경하지 못했습니다: $e');
        }
      }
    }
  }

  /// Only the current owner can change voice consent through its dedicated API.
  Future<void> setParkingCallAllowed(String slotId, bool allowed) =>
      _queueWrite(() => _setParkingCallAllowed(slotId, allowed));

  Future<void> _setParkingCallAllowed(String slotId, bool allowed) async {
    _ensureWritable();
    final current = _state.slotDetails[slotId];
    final email = _auth?.session?.email ?? '';
    if (current == null ||
        !current.isOwnedBy(email) ||
        current.parkingRegistrationId.isEmpty) {
      throw StateError('현재 주차 차주만 통화 수신 설정을 변경할 수 있습니다.');
    }
    final generation = _generation;
    final previousVersion = _state.stateVersion;
    final updated =
        await _services.parkingVoice.setReceiving(slotId, current, allowed);
    if (!_isCurrent(generation) ||
        _state.slotDetails[slotId]?.parkingRegistrationId !=
            current.parkingRegistrationId) {
      return;
    }
    if (updated.parkingRegistrationId != current.parkingRegistrationId) {
      throw StateError('주차 정보가 변경되었습니다. 새로고침 후 다시 시도해 주세요.');
    }
    final details = Map<String, SlotDetail>.from(_state.slotDetails);
    // A simultaneous parking edit may have changed times or labels while the
    // preference request was in flight. Apply only its authoritative voice flag.
    details[slotId] =
        details[slotId]!.copyWith(callAllowed: updated.callAllowed);
    _state = _withSlotDetails(_state, details);
    unawaited(StateCache.save(_state, owner: email));
    notifyListeners();
    // This endpoint also advances the global state version. Do not attach that
    // version to a partial local snapshot: it could authorize a stale admin CAS.
    // Fetch directly inside the write queue; refresh() would wait on this write.
    try {
      invalidateStateCache();
      final fresh = await _services.state.fetch();
      if (!_isCurrent(generation)) return;
      if (fresh.stateVersion <= previousVersion) {
        throw StateError('최신 주차 상태를 확인하지 못했습니다.');
      }
      _state = fresh;
      _lastUpdated = DateTime.now();
      unawaited(StateCache.save(_state, owner: email));
      notifyListeners();
    } catch (error) {
      if (error is ApiException) _auth?.handleApiError(error);
      throw StateError('통화 수신 설정은 저장되었지만 최신 주차 상태를 불러오지 못했습니다. '
          '새로고침 후 다시 시도해 주세요.');
    }
  }

  /// 주차 해제 (출차).
  Future<void> clearSlotDetail(String slotId) =>
      _queueWrite(() => _clearSlotDetail(slotId));

  Future<void> _clearSlotDetail(String slotId) async {
    _ensureWritable();
    final generation = _generation;
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
      if (_isCurrent(generation)) notifyListeners();
    } catch (e) {
      if (_isCurrent(generation)) {
        _state = snapshot;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// 관리자 전용 — 주차 불가/가능 토글.
  Future<void> toggleSlotBlocked(String slotId) => _queueWrite(() async {
        final current = _state.slotDetails[slotId] ?? const SlotDetail();
        final toggled =
            current.copyWith(parkingBlocked: !current.parkingBlocked);
        await _upsertSlotDetail(slotId: slotId, detail: toggled);
      });

  /// 내 소유 슬롯 id (없으면 null).
  String? findMyOwnedSlot(String email) {
    for (final entry in _state.slotDetails.entries) {
      if (entry.value.isOwnedBy(email)) return entry.key;
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
    _clearMemory();
    ApiClient.instance.etagCache.clear();
    if (!_disposed) notifyListeners();
    await StateCache.clear();
  }

  AppState _withSlotDetails(AppState s, Map<String, SlotDetail> details) {
    return AppState(
      stateVersion: s.stateVersion,
      vehicleVerificationRequired: s.vehicleVerificationRequired,
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
      stateVersion: s.stateVersion,
      vehicleVerificationRequired: s.vehicleVerificationRequired,
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
  Future<void> upsertBeaconPosition(
          {required String beaconId, required BeaconPosition? position}) =>
      _queueWrite(
          () => _upsertBeaconPosition(beaconId: beaconId, position: position));

  Future<void> _upsertBeaconPosition({
    required String beaconId,
    required BeaconPosition? position,
  }) async {
    _ensureWritable();
    final generation = _generation;
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
      if (_isCurrent(generation)) notifyListeners();
    } catch (e) {
      if (_isCurrent(generation)) {
        _state = snapshot;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// 비콘 → 슬롯 매핑 저장. 비콘 ID(MAC) 가 비어 있으면 매핑 제거.
  Future<void> upsertBeaconMapping(
          {required String beaconId, required String slotId}) =>
      _queueWrite(
          () => _upsertBeaconMapping(beaconId: beaconId, slotId: slotId));

  Future<void> _upsertBeaconMapping({
    required String beaconId,
    required String slotId,
  }) async {
    _ensureWritable();
    final generation = _generation;
    final snapshot = _state;
    final next = Map<String, String>.from(snapshot.beaconMappings);
    if (slotId.isEmpty) {
      next.remove(beaconId);
    } else {
      next[beaconId] = slotId;
    }
    _state = AppState(
      stateVersion: snapshot.stateVersion,
      vehicleVerificationRequired: snapshot.vehicleVerificationRequired,
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
      beaconPositions: snapshot.beaconPositions,
    );
    notifyListeners();

    final payload = _stateToPayload(_state);
    try {
      await _saveServerAuthoritative(payload);
      if (_isCurrent(generation)) notifyListeners();
    } catch (e) {
      if (_isCurrent(generation)) {
        _state = snapshot;
        notifyListeners();
      }
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
      'stateVersion': s.stateVersion,
      'vehicleVerificationRequired': s.vehicleVerificationRequired,
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
    _disposed = true;
    _generation++;
    _auth?.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    stop();
    super.dispose();
  }
}
