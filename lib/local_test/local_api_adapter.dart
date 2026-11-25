import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/app_state.dart';
import '../models/parking_slot.dart';
import '../core/plate_recognition.dart';
import 'local_member_management.dart';
import 'local_community.dart';

/// In-memory API fixture for the isolated local member test app. It never
/// opens a socket and only accepts the fixed [baseUrl] origin.
class LocalApiAdapter implements HttpClientAdapter {
  LocalApiAdapter({this.admin = false});

  /// Applies only to the isolated debug fixture, never to a real session.
  final bool admin;
  static const baseUrl = 'https://local-test.invalid';
  static const memberEmail = 'local-member@example.invalid';
  static const _initialNickname = '테스트 회원';
  static const _initialVehicle = '12가3456';
  static const _timestamp = '2026-10-09T09:00:00.000Z';

  bool _authenticated = true;
  bool _consented = true;
  bool _closed = false;
  String _nickname = _initialNickname;
  String _vehicle = _initialVehicle;
  bool _approved = true;
  bool _ocrMatched = true;
  int _vehicleSubmissionVersion = 1;
  int _nextHistoryId = 1;
  int _nextChatId = 1;
  final List<Map<String, dynamic>> _history = [];
  final List<Map<String, dynamic>> _messages = [];
  late final Map<String, dynamic> _state = _initialState();
  final _members = LocalMemberManagement(memberEmail);
  late final _community = LocalCommunity(memberEmail, admin: admin);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      return _response(503, _error('adapter closed'));
    }
    if (options.uri.origin != baseUrl) {
      return _response(403, _error('local adapter origin rejected'));
    }
    final method = options.method.toUpperCase();
    final path = options.uri.path;
    final query = options.uri.queryParameters;
    final data = await _readBody(requestStream);

    if (path == '/api/auth') {
      if (method == 'GET') {
        return _response(200, _authBody());
      }
      if (method == 'POST') {
        if (data['action'] == 'logout') {
          _authenticated = false;
          return _response(200, {'ok': true});
        }
        if (data.containsKey('googleCredential')) {
          _authenticated = true;
          return _response(200, _authBody());
        }
        return _response(400, _error('unsupported local auth action'));
      }
    }

    if (path == '/api/public-dashboard' && method == 'GET') {
      return _response(200, {'ok': true, 'state': _redactedState()});
    }
    if (path == '/api/public-highlight' && method == 'GET') {
      return _response(200, {
        'ok': true,
        'totalActive': _history.where((h) => h['status'] == 'active').length,
        'groups': <dynamic>[],
      });
    }

    if (path == '/api/admin-members' ||
        (admin && path == '/api/users' && method == 'GET')) {
      if (!_authenticated) {
        return _response(401, _error('authentication required'));
      }
      if (!admin) return _response(403, _error('admin required'));
      final result = method == 'GET'
          ? _members.list(query)
          : _members.mutate(method, data);
      if (method == 'GET' && result['users'] is List) {
        result['users'] = (result['users'] as List)
            .map((user) => {
                  ...Map<String, dynamic>.from(user as Map),
                  'vehicleVerificationRequired':
                      _state['vehicleVerificationRequired'] != false,
                  'vehicleVerificationExempt': false,
                })
            .toList();
      }
      return _response(result['ok'] == true ? 200 : 400, result);
    }
    if (path == '/api/member-notices' && method == 'GET') {
      if (!_authenticated) {
        return _response(401, _error('authentication required'));
      }
      return _response(200, _members.notices(memberEmail));
    }
    if (path.startsWith('/api/admin') ||
        path == '/api/users' ||
        path == '/api/logs' ||
        (path == '/api/my-history' && query.containsKey('email'))) {
      return _response(403, _error('admin routes are unavailable locally'));
    }
    if (!_authenticated && _memberRoute(path)) {
      return _response(401, {
        ..._error('authentication required'),
        'authStatus': 'unknown',
      });
    }
    if (!_authenticated &&
        (path == '/api/board' || path == '/api/charger-reports')) {
      return _response(401, _error('authentication required'));
    }
    if (!_approved &&
        (_memberRoute(path) && path != '/api/profile' ||
            path == '/api/board' ||
            path == '/api/charger-reports')) {
      return _response(
          403, {..._error('approval required'), 'authStatus': 'pending'});
    }
    if (path == '/api/parking-voice') {
      if (method == 'GET' && query['action'] == 'capability') {
        return _response(
            200, {'ok': true, 'enabled': false, 'reason': 'DISABLED'});
      }
      if (method == 'GET' && query['action'] == 'inbox') {
        return _response(200, {'ok': true, 'calls': <dynamic>[]});
      }
      return _response(
          503, _error('Voice media is disabled in the local fixture'));
    }
    final community = _community.handle(method, path, query, data);
    if (community != null) {
      return _response(community['ok'] == true ? 200 : 400, community);
    }

    if (path == '/api/state') {
      if (method == 'GET') {
        return _response(200, {'ok': true, 'state': _copy(_state)});
      }
      if (method == 'POST') {
        return _saveState(data);
      }
    }
    if (path == '/api/profile') {
      if (method == 'GET') {
        return _response(200, {'ok': true, 'profile': _profile()});
      }
      if (method == 'POST') {
        return _updateProfile(data);
      }
      if (method == 'DELETE') {
        _authenticated = false;
        return _response(200, {'ok': true});
      }
    }
    if (path == '/api/my-history' && method == 'GET') {
      return _response(200, {
        'ok': true,
        'user': _profile(),
        'history': _history.map(_copy).toList(),
      });
    }
    if (path == '/api/chat') {
      if (method == 'GET') {
        final afterId = int.tryParse(query['after'] ?? '') ?? 0;
        final limit = int.tryParse(query['limit'] ?? '') ?? 30;
        final visible = _messages
            .where((m) => (m['id'] as int) > afterId)
            .take(limit)
            .map(_copy)
            .toList();
        return _response(200, {'ok': true, 'messages': visible});
      }
      if (method == 'POST') {
        return _createChat(data);
      }
      if (method == 'PUT') {
        return _editChat(query, data);
      }
      if (method == 'DELETE') {
        return _deleteChat(query);
      }
    }

    return _response(404, _error('unknown local route'));
  }

  bool _memberRoute(String path) => const {
        '/api/parking-voice',
        '/api/state',
        '/api/profile',
        '/api/my-history',
        '/api/chat',
      }.contains(path);

  Future<Map<String, dynamic>> _readBody(Stream<Uint8List>? stream) async {
    if (stream == null) {
      return {};
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      return {};
    }
    final value = jsonDecode(utf8.decode(bytes));
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  ResponseBody _response(int status, Map<String, dynamic> json) =>
      ResponseBody.fromString(
        jsonEncode(json),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  Map<String, dynamic> _error(String message) =>
      {'ok': false, 'error': message};
  Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  Map<String, dynamic> _authBody() => {
        'ok': true,
        'vehicleVerificationRequired':
            _state['vehicleVerificationRequired'] != false,
        'googleEnabled': false,
        'googleClientId': null,
        'session': _authenticated
            ? {
                'email': memberEmail,
                'name': _initialNickname,
                'nickname': _nickname,
                'picture': '',
                'role': admin ? 'admin' : 'user',
                'status': _approved ? 'approved' : 'pending',
                'approved': _approved,
                'authType': 'local-test',
                'vehicleNumber': _vehicle,
                'profileComplete': _ocrMatched ||
                    _state['vehicleVerificationRequired'] == false,
                'vehicleVerificationRequired':
                    _state['vehicleVerificationRequired'] != false,
              }
            : null,
        'needsConsent': !_consented,
        'needsPhotoVerification': false,
        'users': <dynamic>[],
      };

  Map<String, dynamic> _profile() => {
        'email': memberEmail,
        'name': _initialNickname,
        'nickname': _nickname,
        'picture': '',
        'status': _approved ? 'approved' : 'pending',
        'role': admin ? 'admin' : 'user',
        'vehicleNumber': _vehicle,
        'profileComplete':
            _ocrMatched || _state['vehicleVerificationRequired'] == false,
        'vehicleVerificationRequired':
            _state['vehicleVerificationRequired'] != false,
        'vehicleVerificationExempt': false,
        'vehicleVerified': _approved,
        'ocrMatched': _ocrMatched,
        'vehicleSubmissionVersion': _vehicleSubmissionVersion,
        'createdAt': _timestamp,
        'approvedAt': _timestamp,
        'approvedBy': 'local-test',
        'consentAt': _consented ? _timestamp : null,
      };

  ResponseBody _updateProfile(Map<String, dynamic> data) {
    if (data['action'] == 'consent') {
      _consented = true;
      return _response(200, {'ok': true});
    }
    final vehicle = data['vehicleNumber'];
    if (!_consented) return _response(409, _error('consent required'));
    final nickname = data['nickname'];
    if (nickname is! String ||
        nickname.trim().isEmpty ||
        nickname.trim().length > 30) {
      return _response(400, _error('nickname required (1..30)'));
    }
    if (vehicle is! String || !isSinglePlate(vehicle)) {
      return _response(400, _error('vehicleNumber required'));
    }
    final normalized = vehicle.replaceAll(RegExp(r'[\s-]'), '');
    final changed = normalized != _vehicle;
    if (changed ||
        data['vehiclePhoto'] != null ||
        data['ocrCandidates'] != null) {
      final photo = data['vehiclePhoto'];
      final candidates = data['ocrCandidates'];
      final requiresPhoto = _state['vehicleVerificationRequired'] != false;
      if (requiresPhoto &&
          (photo is! String ||
              !photo.startsWith('data:image/') ||
              candidates is! List ||
              !candidates.any((c) =>
                  c is String &&
                  c.replaceAll(RegExp(r'[\s-]'), '') == normalized))) {
        return _response(400, _error('matching OCR and plate photo required'));
      }
      _approved = false;
      _ocrMatched = requiresPhoto;
      _vehicleSubmissionVersion++;
    }
    _vehicle = normalized;
    _nickname = nickname.trim();
    return _response(200, {'ok': true, 'profile': _profile()});
  }

  ResponseBody _saveState(Map<String, dynamic> data) {
    if (data.containsKey('vehicleVerificationRequired') &&
        data['vehicleVerificationRequired'] is! bool) {
      return _response(400, _error('invalid verification policy'));
    }
    if (!admin &&
        data.containsKey('vehicleVerificationRequired') &&
        data['vehicleVerificationRequired'] !=
            _state['vehicleVerificationRequired']) {
      return _response(
          403, _error('admin required to change verification policy'));
    }
    final rawIncoming = data['slotDetails'];
    if (rawIncoming is! Map) {
      return _response(400, _error('slotDetails is required'));
    }
    if (admin) {
      if (data.containsKey('vehicleVerificationRequired')) {
        _state['vehicleVerificationRequired'] =
            data['vehicleVerificationRequired'];
      }
      _state['slotDetails'] = _copy(Map<String, dynamic>.from(rawIncoming));
      return _response(200, {'ok': true, 'state': _copy(_state)});
    }
    final current = Map<String, dynamic>.from(_state['slotDetails'] as Map);
    final incoming = Map<String, dynamic>.from(rawIncoming);
    final next = Map<String, dynamic>.from(current);
    final historyEvents = <Map<String, dynamic>>[];

    for (final entry in incoming.entries) {
      final id = entry.key.toString();
      if (entry.value is! Map) {
        return _response(400, _error('invalid slot detail'));
      }
      final previous =
          Map<String, dynamic>.from(current[id] as Map? ?? const {});
      final proposed = Map<String, dynamic>.from(entry.value as Map);
      if (_same(previous, proposed)) {
        continue;
      }
      if (previous['parkingBlocked'] == true ||
          proposed['parkingBlocked'] == true) {
        return _response(403, _error('blocked slot cannot be changed'));
      }
      final oldOwner = previous['ownerEmail'] ?? '';
      final newOwner = proposed['ownerEmail'] ?? '';
      if (oldOwner.isNotEmpty && oldOwner != memberEmail) {
        return _response(403, _error('slot belongs to another member'));
      }
      if (newOwner.isNotEmpty && newOwner != memberEmail) {
        return _response(403, _error('cannot claim another member identity'));
      }
      if (oldOwner == memberEmail && newOwner.isEmpty) {
        _completeHistory(id, previous, historyEvents);
      } else if (oldOwner.isEmpty && newOwner == memberEmail) {
        historyEvents.add(_historyRecord(id, proposed, ended: false));
      }
      if (proposed.isEmpty ||
          (newOwner.isEmpty &&
              proposed.values.every((v) => v == '' || v == false))) {
        next.remove(id);
      } else {
        next[id] = proposed;
      }
    }

    // StateApi sends the complete state. A member's omitted slot represents a
    // release because AppStateProvider removes that detail before saving.
    for (final entry in current.entries) {
      if (incoming.containsKey(entry.key)) {
        continue;
      }
      final previous = Map<String, dynamic>.from(entry.value as Map);
      if (previous['ownerEmail'] == memberEmail) {
        _completeHistory(entry.key, previous, historyEvents);
        next.remove(entry.key);
      }
    }

    for (final event in historyEvents) {
      final replacedId = event.remove('_replacesHistoryId');
      if (replacedId is int) {
        final index =
            _history.indexWhere((record) => record['id'] == replacedId);
        if (index >= 0) {
          _history[index] = event;
          continue;
        }
      }
      _history.add(event);
    }
    _state['slotDetails'] = next;
    return _response(200, {'ok': true, 'state': _copy(_state)});
  }

  bool _same(Map<String, dynamic> left, Map<String, dynamic> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final key in left.keys) {
      if (!right.containsKey(key) || !_sameValue(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }

  bool _sameValue(Object? left, Object? right) {
    if (left is Map && right is Map) {
      return _same(
          Map<String, dynamic>.from(left), Map<String, dynamic>.from(right));
    }
    if (left is List && right is List) {
      if (left.length != right.length) {
        return false;
      }
      for (var i = 0; i < left.length; i++) {
        if (!_sameValue(left[i], right[i])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }

  void _completeHistory(
    String slotId,
    Map<String, dynamic> detail,
    List<Map<String, dynamic>> pendingEvents,
  ) {
    for (var i = _history.length - 1; i >= 0; i--) {
      final record = _history[i];
      if (record['slotId'] == slotId &&
          record['userEmail'] == memberEmail &&
          record['status'] == 'active') {
        pendingEvents.add({
          ...record,
          'status': 'completed',
          'endTime': DateTime.now().toUtc().toIso8601String(),
          '_replacesHistoryId': record['id'],
        });
        return;
      }
    }
    pendingEvents.add(_historyRecord(slotId, detail, ended: true));
  }

  Map<String, dynamic> _historyRecord(
    String slotId,
    Map<String, dynamic> detail, {
    required bool ended,
  }) =>
      {
        'id': _nextHistoryId++,
        'userEmail': memberEmail,
        'slotId': slotId,
        'vehicleNumber': detail['vehicleNumber'] ?? _vehicle,
        'contact': '',
        'startTime': detail['startTime'] ?? _timestamp,
        'endTime': ended ? DateTime.now().toUtc().toIso8601String() : null,
        'chargeDuration': detail['chargeDuration'] ?? '1시간',
        'status': ended ? 'completed' : 'active',
        'createdAt': _timestamp,
      };

  ResponseBody _createChat(Map<String, dynamic> data) {
    final text = (data['message'] as String? ?? '').trim();
    if (text.isEmpty) {
      return _response(400, _error('message is required'));
    }
    final message = <String, dynamic>{
      'id': _nextChatId++,
      'authorEmail': memberEmail,
      'authorNickname': _nickname,
      'authorRole': 'user',
      'message': text,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    _messages.add(message);
    return _response(201, {'ok': true, 'message': _copy(message)});
  }

  ResponseBody _editChat(Map<String, String> query, Map<String, dynamic> data) {
    final id = int.tryParse(query['id'] ?? '');
    final index = _messages
        .indexWhere((m) => m['id'] == id && m['authorEmail'] == memberEmail);
    if (index < 0) {
      return _response(404, _error('message not found'));
    }
    final text = (data['message'] as String? ?? '').trim();
    if (text.isEmpty) {
      return _response(400, _error('message is required'));
    }
    _messages[index]['message'] = text;
    _messages[index]['editedAt'] = DateTime.now().toUtc().toIso8601String();
    return _response(200, {'ok': true, 'message': _copy(_messages[index])});
  }

  ResponseBody _deleteChat(Map<String, String> query) {
    final id = int.tryParse(query['id'] ?? '');
    final index = _messages
        .indexWhere((m) => m['id'] == id && m['authorEmail'] == memberEmail);
    if (index < 0) {
      return _response(404, _error('message not found'));
    }
    _messages.removeAt(index);
    return _response(200, {'ok': true});
  }

  Map<String, dynamic> _redactedState() {
    final state = _copy(_state);
    final details = Map<String, dynamic>.from(state['slotDetails'] as Map);
    for (final entry in details.entries.toList()) {
      final detail = Map<String, dynamic>.from(entry.value as Map);
      final occupied = detail['parkingBlocked'] != true &&
          ((detail['vehicleNumber'] as String? ?? '').isNotEmpty ||
              (detail['ownerEmail'] as String? ?? '').isNotEmpty);
      details[entry.key] = occupied
          ? {'vehicleNumber': '점유 중', 'parkingBlocked': false}
          : {'parkingBlocked': detail['parkingBlocked'] == true};
    }
    state['slotDetails'] = details;
    return state;
  }

  Map<String, dynamic> _initialState() {
    final state = AppState.empty().toJson();
    final details = Map<String, dynamic>.from(state['slotDetails'] as Map);
    details['fast50-2'] = const SlotDetail(
      vehicleNumber: '34나5678',
      contact: '',
      contactVisible: false,
      startTime: _timestamp,
      departureTime: '10:00',
      chargeDuration: '1시간',
      ownerEmail: 'other-member@example.invalid',
      ownerNickname: '다른 회원',
    ).toJson();
    details['fast50-3'] = const SlotDetail(parkingBlocked: true).toJson();
    state['slotDetails'] = details;
    final positions =
        Map<String, dynamic>.from(state['slotMapPositions'] as Map);
    positions['fast50-1'] = {'floor': 'B1', 'x': 20.0, 'y': 25.0};
    positions['fast50-2'] = {'floor': 'B1', 'x': 40.0, 'y': 25.0};
    positions['fast50-3'] = {'floor': 'B1', 'x': 60.0, 'y': 25.0};
    state['slotMapPositions'] = positions;
    return state;
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }
}
