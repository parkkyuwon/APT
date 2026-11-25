import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/errors.dart';
import '../models/parking_slot.dart';
import '../providers/auth_provider.dart';
import 'parking_voice_api.dart';
import 'parking_voice_peer.dart';

/// Foreground-only audio. Server grants never outlive the local hard lease.
class ParkingVoiceController extends ChangeNotifier
    with WidgetsBindingObserver {
  ParkingVoiceController(this._api, this._auth,
      {VoicePeerFactory? peerFactory, DateTime Function()? now})
      : _peerFactory = peerFactory ?? WebRtcVoicePeer.new,
        _now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_accountChanged);
    _account = _identity;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null ||
        lifecycle == AppLifecycleState.resumed ||
        lifecycle == AppLifecycleState.inactive;
    _pollTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => unawaited(refresh()));
    _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => unawaited(_heartbeat()));
    _leaseTimer = Timer.periodic(
        const Duration(milliseconds: 250), (_) => _checkDeadline());
    unawaited(refresh());
  }

  final ParkingVoiceApi _api;
  final AuthProvider _auth;
  final VoicePeerFactory _peerFactory;
  final DateTime Function() _now;
  late final Timer _pollTimer;
  late final Timer _heartbeatTimer;
  late final Timer _leaseTimer;
  String? _account;
  bool _disposed = false;
  bool _foreground = true;
  bool _available = false;
  bool _capabilityChecked = false;
  DateTime? _capabilityRetryAt;
  bool _polling = false;
  bool _heartbeatBusy = false;
  bool _busy = false;
  bool _opening = false;
  bool _connected = false;
  bool _muted = false;
  bool _speaker = false;
  bool _offered = false;
  int _generation = 0;
  int _sequence = 0;
  VoicePeer? _peer;
  Map<String, dynamic>? _active;
  List<Map<String, dynamic>> _incoming = [];
  DateTime? _deadline;
  DateTime? _maximumDeadline;
  Timer? _hardLeaseTimer;
  Timer? _maximumTimer;
  String _reason = '앱 통화 준비 상태를 확인하고 있습니다.';
  String? _message;
  Future<void> _outgoingSignals = Future<void>.value();

  bool get available => _available && _identity != null && _foreground;
  String get unavailableReason => _reason;
  Map<String, dynamic>? get activeCall =>
      _active == null ? null : Map.unmodifiable(_active!);
  List<Map<String, dynamic>> get incomingCalls => List.unmodifiable(_incoming);
  bool get busy => _busy;
  bool get connected => _connected;
  bool get muted => _muted;
  bool get speakerEnabled => _speaker;
  String? get message => _message;

  String? get _identity =>
      (_auth.stage == AuthStage.approved || _auth.stage == AuthStage.admin)
          ? _auth.session?.email.trim().toLowerCase()
          : null;
  bool _current(int generation) =>
      !_disposed &&
      _foreground &&
      generation == _generation &&
      _account != null &&
      _identity == _account;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String? get _callId =>
      _active?['id'] is String ? _active!['id'] as String : null;
  bool _terminal(Map<String, dynamic> call) =>
      !['ringing', 'accepted'].contains(call['status']);

  void _accountChanged() {
    if (_identity == _account) return;
    _stop(_active != null || _incoming.isNotEmpty
        ? '계정이 변경되어 통화를 종료했습니다.'
        : null);
    _account = _identity;
    _available = false;
    _capabilityChecked = false;
    if (_account != null) unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _capabilityChecked = false;
      unawaited(refresh());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _stop(_active != null || _incoming.isNotEmpty
          ? '앱이 화면을 벗어나 통화를 종료했습니다.'
          : null);
    }
  }

  DateTime _limitedDeadline(Object? raw, Duration maximum) {
    final local = _now().add(maximum);
    final server = raw is String ? DateTime.tryParse(raw) : null;
    return server != null && server.isBefore(local) ? server : local;
  }

  // Timer durations remain bounded even if the device wall clock moves back.
  void _armLease(DateTime deadline, Duration maximum) {
    _deadline = deadline;
    final remaining = deadline.difference(_now());
    final duration = remaining.isNegative
        ? Duration.zero
        : remaining > maximum
            ? maximum
            : remaining;
    _hardLeaseTimer?.cancel();
    final generation = _generation;
    _hardLeaseTimer = Timer(duration, () {
      if (_current(generation)) {
        _stop('연결 확인 시간이 지나 통화를 종료했습니다.');
      }
    });
  }

  void _rememberCall(Map<String, dynamic> call, {bool grantLease = false}) {
    if (call['id'] is! String || call['id'].toString().isEmpty) {
      throw StateError('Missing call');
    }
    _active = Map<String, dynamic>.from(call);
    if (_terminal(call)) {
      _stop('통화가 종료되었습니다.', sendEnd: false);
      return;
    }
    if (call['status'] == 'ringing') {
      if (_deadline == null) {
        _armLease(
            _limitedDeadline(
                call['ringExpiresAt'], const Duration(seconds: 30)),
            const Duration(seconds: 30));
      }
    } else {
      final firstAccepted = _maximumDeadline == null;
      _maximumDeadline ??= _now().add(const Duration(minutes: 3));
      if (firstAccepted) {
        final generation = _generation;
        _maximumTimer = Timer(const Duration(minutes: 3), () {
          if (_current(generation)) _stop('최대 통화 시간 3분이 지났습니다.');
        });
      }
      if (firstAccepted || grantLease) {
        var deadline = _limitedDeadline(
            call['leaseExpiresAt'], const Duration(seconds: 15));
        if (deadline.isAfter(_maximumDeadline!)) deadline = _maximumDeadline!;
        _armLease(deadline, const Duration(seconds: 15));
      }
    }
  }

  void _checkDeadline() {
    if (_active != null && _deadline != null && !_now().isBefore(_deadline!)) {
      _stop('연결 확인 시간이 지나 통화를 종료했습니다.');
    }
  }

  Future<void> refresh() async {
    if (_disposed || !_foreground || _identity == null || _polling) return;
    _checkDeadline();
    _polling = true;
    final generation = _generation;
    try {
      if (!_capabilityChecked ||
          (!_available &&
              _capabilityRetryAt != null &&
              !_now().isBefore(_capabilityRetryAt!))) {
        _capabilityChecked = true;
        _capabilityRetryAt = _now().add(const Duration(seconds: 60));
        final capability = await _api.fetchCapability();
        if (!_current(generation)) return;
        _available = capability['enabled'] == true;
        _capabilityChecked = true;
        _reason = _available ? '' : '앱 음성통화 연결을 준비하고 있습니다.';
        _notify();
      }
      if (!_available) return;
      final id = _callId;
      if (id == null) {
        final calls = await _api.inbox();
        if (!_current(generation)) return;
        _incoming = calls
            .where((call) =>
                call['status'] == 'ringing' &&
                call['isCaller'] != true &&
                _limitedDeadline(
                        call['ringExpiresAt'], const Duration(seconds: 30))
                    .isAfter(_now()))
            .toList();
      } else {
        final body = await _api.poll(id, _sequence);
        if (!_current(generation) || _callId != id) return;
        final call = Map<String, dynamic>.from(body['call'] as Map);
        _rememberCall(call);
        if (!_current(generation) || _active == null) return;
        if (call['status'] == 'accepted') {
          await _openPeer(generation, id);
          if (!_current(generation) || _peer == null || _opening) return;
          final signals = (body['signals'] as List? ?? [])
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList()
            ..sort((a, b) =>
                (a['sequence'] as int).compareTo(b['sequence'] as int));
          for (final signal in signals) {
            final sequence = signal['sequence'] as int;
            if (sequence <= _sequence) continue;
            await _peer!.receive(signal['type'] as String,
                Map<String, dynamic>.from(signal['payload'] as Map));
            if (!_current(generation)) return;
            _sequence = sequence;
          }
        }
      }
      _notify();
    } catch (error) {
      if (_current(generation)) {
        _message = _error(error);
        if (_active != null && _fatal(error)) _stop(_message);
        _notify();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> startCall(String slotId, SlotDetail detail) async {
    if (_disposed ||
        !_foreground ||
        _identity == null ||
        _busy ||
        _active != null) {
      return;
    }
    if (!_capabilityChecked) await refresh();
    if (!available) {
      _message = _reason;
      _notify();
      return;
    }
    if (!detail.callAllowed ||
        detail.parkingRegistrationId.isEmpty ||
        detail.startTime.isEmpty ||
        detail.isOwnedBy(_identity!)) {
      _message = '현재 통화를 허용한 다른 차량의 주차 정보를 다시 확인해 주세요.';
      _notify();
      return;
    }
    final generation = _generation;
    _busy = true;
    _message = null;
    _notify();
    try {
      final call = await _api.create(slotId, detail);
      if (!_current(generation)) {
        final id = call['id'];
        if (id is String) {
          unawaited(_api
              .action(id, 'cancel')
              .catchError((Object _) => <String, dynamic>{}));
        }
        return;
      }
      _rememberCall(call);
    } catch (error) {
      if (_current(generation)) _message = _error(error);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> accept(Map<String, dynamic> incoming) async {
    if (!available || _busy || _active != null || incoming['id'] is! String) {
      return;
    }
    final generation = _generation;
    final id = incoming['id'] as String;
    _busy = true;
    _message = null;
    _notify();
    try {
      final call = await _api.action(id, 'accept');
      if (!_current(generation)) {
        unawaited(_api
            .action(id, 'end')
            .catchError((Object _) => <String, dynamic>{}));
        return;
      }
      _rememberCall(call, grantLease: true);
      _incoming = [];
      if (_active?['status'] == 'accepted') await _openPeer(generation, id);
    } catch (error) {
      if (_current(generation)) _stop(_error(error));
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> reject(Map<String, dynamic> incoming) async {
    if (_busy || incoming['id'] is! String) return;
    final generation = _generation;
    _busy = true;
    _notify();
    try {
      await _api.action(incoming['id'] as String, 'reject');
      if (_current(generation)) {
        _incoming.removeWhere((call) => call['id'] == incoming['id']);
      }
    } catch (error) {
      if (_current(generation)) _message = _error(error);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _openPeer(int generation, String id) async {
    if (_peer != null || _opening || !_current(generation)) return;
    _opening = true;
    try {
      final configuration = await _api.ice(id);
      _checkDeadline();
      if (!_current(generation) || _callId != id) return;
      final servers = configuration['iceServers'];
      final validTurn = servers is List &&
          servers.any((entry) {
            if (entry is! Map) return false;
            final urls = entry['urls'];
            return (urls is List ? urls : [urls]).any((url) =>
                    url is String &&
                    (url.startsWith('turn:') || url.startsWith('turns:'))) &&
                entry['username'] is String &&
                entry['credential'] is String &&
                (entry['credential'] as String).isNotEmpty;
          });
      if (!validTurn) throw StateError('Missing relay configuration');
      final expiry = DateTime.tryParse('${configuration['expiresAt']}');
      if (expiry == null || !expiry.isAfter(_now())) {
        throw StateError('Expired relay configuration');
      }
      var deadline = _limitedDeadline(
          configuration['leaseExpiresAt'], const Duration(seconds: 15));
      if (_maximumDeadline != null && deadline.isAfter(_maximumDeadline!)) {
        deadline = _maximumDeadline!;
      }
      _armLease(deadline, const Duration(seconds: 15));
      _checkDeadline();
      if (!_current(generation)) return;
      final peer = _peerFactory();
      _peer = peer;
      await peer.open(configuration,
          onSignal: (type, payload) =>
              _sendSignal(generation, id, type, payload),
          onConnection: (value) {
            if (_current(generation)) {
              _connected = value;
              _notify();
            }
          },
          onFailure: () {
            if (_current(generation)) _stop('음성 연결을 종료했습니다. 다시 시도해 주세요.');
          });
      if (!_current(generation) || _peer != peer) {
        peer.close();
        return;
      }
      peer.mute(_muted);
      if (_active?['isCaller'] == true && !_offered) {
        _offered = true;
        await peer.offer();
      }
    } catch (error) {
      if (_current(generation)) _stop(_error(error));
    } finally {
      _opening = false;
    }
  }

  void _sendSignal(
      int generation, String id, String type, Map<String, dynamic> payload) {
    _outgoingSignals = _outgoingSignals.then((_) async {
      if (!_current(generation) || _callId != id) return;
      try {
        await _api.signal(id, type, payload);
      } catch (error) {
        if (_current(generation)) _stop(_error(error));
      }
    });
  }

  Future<void> _heartbeat() async {
    if (_heartbeatBusy ||
        _disposed ||
        !_foreground ||
        !(_active?['status'] == 'accepted' ||
            (_active?['status'] == 'ringing' &&
                _active?['isCaller'] == true))) {
      return;
    }
    _heartbeatBusy = true;
    final generation = _generation;
    final id = _callId!;
    try {
      final call = await _api.action(id, 'heartbeat');
      _checkDeadline();
      if (_current(generation) && _callId == id) {
        _rememberCall(call, grantLease: true);
        _checkDeadline();
      }
    } catch (error) {
      if (_current(generation) && _fatal(error)) _stop(_error(error));
    } finally {
      _heartbeatBusy = false;
    }
  }

  void setMuted(bool value) {
    _muted = value;
    _peer?.mute(value);
    _notify();
  }

  Future<void> setSpeaker(bool value) async {
    final generation = _generation;
    try {
      await _peer?.speaker(value);
      if (_current(generation)) {
        _speaker = value;
        _notify();
      }
    } catch (error) {
      if (_current(generation)) {
        _message = '오디오 출력을 변경하지 못했습니다.';
        _notify();
      }
    }
  }

  void end() => _stop('통화를 종료했습니다.');
  void clearMessage() {
    _message = null;
    _notify();
  }

  void _stop(String? message, {bool sendEnd = true}) {
    final call = _active;
    _generation++;
    final peer = _peer;
    _peer = null;
    peer?.mute(true);
    peer?.close();
    _active = null;
    _incoming = [];
    _hardLeaseTimer?.cancel();
    _maximumTimer?.cancel();
    _hardLeaseTimer = null;
    _maximumTimer = null;
    _deadline = null;
    _maximumDeadline = null;
    _connected = false;
    _offered = false;
    _muted = false;
    _speaker = false;
    _sequence = 0;
    _message = message;
    // Media is already disabled before the first asynchronous server request.
    if (sendEnd && call?['id'] is String) {
      final action = call!['status'] == 'ringing' && call['isCaller'] == true
          ? 'cancel'
          : 'end';
      unawaited(_api
          .action(call['id'] as String, action)
          .catchError((Object _) => <String, dynamic>{}));
    }
    _notify();
  }

  static bool _fatal(Object error) =>
      error is! NetworkException &&
      (error is! ApiException ||
          (error.statusCode < 500 && error.statusCode != 429));
  static String _error(Object error) => error is ApiException
      ? error.message
      : error is NetworkException
          ? error.message
          : '통화를 연결하지 못했습니다. 마이크 권한과 네트워크를 확인해 주세요.';

  @override
  void dispose() {
    _disposed = true;
    _stop(null);
    _pollTimer.cancel();
    _heartbeatTimer.cancel();
    _leaseTimer.cancel();
    _auth.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
