import 'dart:async';

import 'package:flutter/widgets.dart';

import 'foreground_nfc.dart';
import 'qr_payload.dart';

/// QR/NFC 링크를 로그인과 홈 초기화가 끝날 때까지 보관한다.
/// [start]는 runApp 이전에 호출해 Navigator보다 먼저 플랫폼 링크를 받는다.
class DeepLink {
  DeepLink._();

  static final _observer = _DeepLinkObserver();
  static final _events = _DeepLinkEvents();
  static final _nfc = ForegroundNfc(handleRoute);
  static final _slotPattern = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');
  static String? _pendingSlotId;
  static String? _processingSlotId;
  static Object? _processingToken;
  static bool _started = false;
  static bool get hasPendingSlot => _pendingSlotId != null;
  static String? get pendingSlotId => _pendingSlotId;

  static void start() {
    if (_started) return;
    WidgetsBinding.instance.addObserver(_observer);
    _started = true;
    captureInitial();
    unawaited(_nfc.start());
  }

  static void stop() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(_observer);
    _started = false;
    unawaited(_nfc.stop());
  }

  static void addListener(VoidCallback listener) =>
      _events.addListener(listener);
  static void removeListener(VoidCallback listener) =>
      _events.removeListener(listener);

  static void captureInitial() {
    handleRoute(WidgetsBinding.instance.platformDispatcher.defaultRouteName);
  }

  /// 앱이 이미 실행 중이어도 동일한 검증과 보관 경로를 사용한다.
  /// 관련 없는 경로는 false를 반환해 Flutter의 기존 라우팅에 맡긴다.
  static bool handleRoute(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.hasAuthority) {
        final expected = Uri.parse(kAppDefaultBaseUrl);
        if (uri.scheme != expected.scheme ||
            uri.host != expected.host ||
            uri.port != expected.port ||
            uri.userInfo.isNotEmpty) {
          return false;
        }
      } else if (uri.hasScheme) {
        return false;
      }
      if (uri.path != '/index.html') return false;
      final values = uri.queryParametersAll['slot'];
      if (values == null || values.length != 1) return false;
      final slot = values.single.trim();
      if (!_slotPattern.hasMatch(slot)) return false;
      setPendingSlot(slot);
      return true;
    } on FormatException {
      return false;
    }
  }

  static String? consumePendingSlot() {
    final id = _pendingSlotId;
    _pendingSlotId = null;
    return id;
  }

  static Object beginSlotHandling(String slotId) {
    _processingSlotId = slotId;
    return _processingToken = Object();
  }

  static void finishSlotHandling(Object token) {
    if (!identical(token, _processingToken)) return;
    _processingSlotId = null;
    _processingToken = null;
  }

  static void setPendingSlot(String slotId) {
    final slot = slotId.trim();
    if (!_slotPattern.hasMatch(slot) ||
        _pendingSlotId == slot ||
        _processingSlotId == slot) {
      return;
    }
    _pendingSlotId = slot;
    _events.publish();
  }
}

class _DeepLinkEvents extends ChangeNotifier {
  void publish() => notifyListeners();
}

class _DeepLinkObserver with WidgetsBindingObserver {
  @override
  Future<bool> didPushRoute(String route) async => DeepLink.handleRoute(route);

  @override
  Future<bool> didPushRouteInformation(
          RouteInformation routeInformation) async =>
      DeepLink.handleRoute(routeInformation.uri.toString());
}
