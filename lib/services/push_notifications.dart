import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/auth_provider.dart';
import 'push_identity.dart';
import 'services.dart';

/// Firebase 설정이 없으면 주차 기능과 앱 내 요청 목록은 그대로 사용할 수 있다.
Future<void> initializeDeparturePush() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  try {
    if (Firebase.apps.isNotEmpty) return;
    if (apiKey.isNotEmpty &&
        appId.isNotEmpty &&
        senderId.isNotEmpty &&
        projectId.isNotEmpty) {
      await Firebase.initializeApp(
          options: const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      ));
    } else {
      // flutterfire configure로 생성한 네이티브 설정도 지원한다.
      await Firebase.initializeApp();
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
  } catch (_) {
    // 키나 원시 플랫폼 오류를 로그에 출력하지 않는다.
    debugPrint('출차 요청 휴대폰 알림 초기화 불가: 앱 내 요청 목록을 사용합니다.');
  }
}

class PushNotifications extends ChangeNotifier with WidgetsBindingObserver {
  PushNotifications(this._services, this._auth) {
    _auth.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    _identity.setAccount(_account);
    _ready = _start().catchError((Object _) {
      _error = '휴대폰 알림 준비 실패 · 앱 내 요청 목록 이용 가능';
      _notify();
    });
    if (_account != null) _enqueue(_registerIfAllowed);
  }
  final ApiServices _services;
  final AuthProvider _auth;
  final _identity = PushIdentity();
  final _local = FlutterLocalNotificationsPlugin();
  late final Future<void> _ready;
  Future<void> _chain = Future.value();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _disposed = false;
  bool _enabled = false;
  bool _tokenResetPending = false;
  String? _error;
  int? _pendingRequestId;

  bool get configured =>
      !kIsWeb &&
      Firebase.apps.isNotEmpty &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool get enabled => _enabled && _identity.registered;
  String get status => !configured
      ? '휴대폰 알림 준비 중 · 앱 내 요청 목록 이용 가능'
      : enabled
          ? '휴대폰 알림 사용 중'
          : _error ?? '휴대폰 알림을 켜 주세요';
  int? get pendingRequestId => _pendingRequestId;
  String? get _account =>
      (_auth.stage == AuthStage.approved || _auth.stage == AuthStage.admin)
          ? _auth.session?.email
          : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _start() async {
    if (!configured) return;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_departure'),
        iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = int.tryParse(response.payload ?? '');
        if (id != null && id > 0) _open(id);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'departure_requests',
          '출차 요청',
          description: '다른 차량의 출차 요청 알림',
          importance: Importance.high,
        ));
    // iOS에서도 현재 계정의 요청인지 재조회한 뒤 로컬 알림을 표시한다.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
            alert: false, badge: false, sound: false);
    if (_disposed) return;
    _subscriptions.add(FirebaseMessaging.onMessage.listen((message) {
      final id = departureRequestId(message.data);
      if (id != null) _enqueue(() => _foreground(id));
    }));
    _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final id = departureRequestId(message.data);
      if (id != null) _open(id);
    }));
    _subscriptions.add(FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      if (_account != null) _enqueue(_registerIfAllowed);
    }));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    final launch = await _local.getNotificationAppLaunchDetails();
    if (_disposed) return;
    final id = initial == null
        ? int.tryParse(launch?.notificationResponse?.payload ?? '')
        : departureRequestId(initial.data);
    if (id != null && id > 0) _open(id);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _chain = _chain.then((_) async {
      await _ready;
      if (!_disposed && configured) await action();
    }).catchError((Object _) {
      _error = '휴대폰 알림 연결 실패 · 다시 시도해 주세요';
      _notify();
    });
    return _chain;
  }

  void _accountChanged() {
    if (_identity.account == _account) return;
    final hadAccount = _identity.account != null;
    _identity.setAccount(_account);
    _pendingRequestId = null;
    _enabled = false;
    _error = null;
    if (hadAccount) _tokenResetPending = true;
    _notify();
    _enqueue(() async {
      if (!await _resetIfPending()) return;
      await _registerIfAllowed();
    });
  }

  Future<void> enable() => _enqueue(() async {
        if (_account == null) return;
        await FirebaseMessaging.instance
            .requestPermission(alert: true, badge: true, sound: true);
        await _registerIfAllowed();
      });

  Future<void> _registerIfAllowed() async {
    if (!await _resetIfPending()) return;
    final account = _account;
    if (account == null || _disposed) return;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (account != _account || _disposed) return;
    _enabled = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!_enabled) {
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      _notify();
      return;
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    if (account != _account || _disposed) return;
    await _identity.bind(account,
        obtainToken: () async {
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            final apns = await waitForApnsToken(
                read: FirebaseMessaging.instance.getAPNSToken,
                isCurrent: () => !_disposed && account == _account,
                delay: () =>
                    Future<void>.delayed(const Duration(milliseconds: 500)));
            if (apns == null) throw StateError('APNs token not ready');
          }
          return FirebaseMessaging.instance.getToken();
        },
        register: (token) => _services.departureRequests.registerToken(token,
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'));
    if (account == _account && !_disposed) {
      _error = null;
      _notify();
    }
  }

  Future<bool> _resetIfPending() async {
    if (!_tokenResetPending) return true;
    final reset = await resetPushRegistration(
        clearNotifications: _local.cancelAll,
        disableAutoInit: () =>
            FirebaseMessaging.instance.setAutoInitEnabled(false),
        deleteToken: FirebaseMessaging.instance.deleteToken);
    _tokenResetPending = !reset;
    if (!reset) {
      _error = '휴대폰 알림 정리 대기 중 · 연결 후 다시 시도';
      _notify();
    }
    return reset;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enqueue(_registerIfAllowed);
  }

  Future<void> _foreground(int id) async {
    final account = _account;
    if (account == null || !enabled) return;
    final request = await _services.departureRequests.get(id);
    if (account != _account || _disposed) return;
    await _local.show(
        id: request.id % 2147483647,
        title: '출차 요청',
        body:
            '${request.requesterVehicleNumber} 차량이 ${request.slotName.isEmpty ? request.slotId : request.slotName}의 출차를 요청했습니다.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('departure_requests', '출차 요청',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_departure'),
          iOS: DarwinNotificationDetails(
              presentAlert: true, presentSound: true, presentBadge: true),
        ),
        payload: '$id');
  }

  void _open(int id) {
    if (_disposed) return;
    _pendingRequestId = id;
    _notify();
  }

  int? takePendingRequest() {
    if (_account == null) return null;
    final id = _pendingRequestId;
    _pendingRequestId = null;
    return id;
  }

  @override
  void dispose() {
    _disposed = true;
    _identity.setAccount(null);
    _auth.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
