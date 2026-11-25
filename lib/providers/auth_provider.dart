import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../core/errors.dart';
import '../core/api_client.dart';
import '../core/session_info_cache.dart';
import '../models/session.dart';
import '../services/services.dart';

enum AuthStage {
  /// 초기 로딩 (세션 복원 시도 중)
  initializing,

  /// 비로그인
  anonymous,

  /// 비회원 게스트 — 읽기 전용 주차 현황 모니터링
  guest,

  /// 관리자 승인 대기 (pending)
  pending,

  /// 로그인 됐으나 약관 동의 필요
  needsConsent,

  /// 로그인 됐으나 차량번호/OCR 입력 필요
  needsProfileSetup,

  /// 로그인 됐으나 차량 사진 인증 필요
  needsPhotoVerification,

  /// 정상 승인 사용자
  approved,

  /// 관리자
  admin,

  /// 거절/차단/탈퇴 등
  blocked,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._services);

  final ApiServices _services;

  bool _googleInitialized = false;
  int _generation = 0;
  bool _disposed = false;

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  AuthStage _stage = AuthStage.initializing;
  SessionInfo? _session;
  String? _errorMessage;
  bool _isBusy = false;

  AuthStage get stage => _stage;
  SessionInfo? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isBusy;

  bool get isAuthenticated => _session != null;
  bool get isAdmin => _session?.isAdmin == true;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId,
    );
    _googleInitialized = true;
  }

  /// 앱 시작 시 세션 쿠키 + 영속 캐시로 복원 시도.
  ///
  /// 1) SessionInfoCache 에 캐시된 세션이 있으면 즉시 적용해 ShellScreen 진입
  ///    → 콜드 스타트 시 "로그인 화면 깜빡임" 제거
  /// 2) 동시에 백엔드 /api/auth 호출, 응답 차이 발견 시 무음 갱신
  /// 3) 401 응답이면 캐시 무효화 + 익명 상태로
  Future<void> bootstrap() async {
    final generation = ++_generation;
    final cached = await SessionInfoCache.load();
    if (!_isCurrent(generation)) return;
    if (cached != null) {
      _session = cached;
      _applyStageFromSession(cached);
      // busy=false 유지 — 캐시 결과 즉시 노출
      notifyListeners();
    } else {
      _setBusy(true);
    }

    try {
      final result = await _services.auth.fetchSession();
      if (!_isCurrent(generation)) return;
      _applyBootstrap(result);
      if (result.session != null) {
        unawaited(SessionInfoCache.save(result.session!));
      } else {
        unawaited(SessionInfoCache.clear());
      }
    } on ApiException catch (e) {
      if (!_isCurrent(generation)) return;
      if (handleApiError(e)) {
        return;
      }
      if (cached == null) {
        _errorMessage = e.message;
        _stage = AuthStage.anonymous;
        _session = null;
      }
      // 캐시 적중 + 비-401 오류면 캐시된 상태 유지
    } on NetworkException catch (e) {
      if (!_isCurrent(generation)) return;
      // 네트워크 오류 — 캐시가 있으면 그대로 사용 (오프라인 진입 가능)
      if (cached == null) {
        _errorMessage = e.message;
        _stage = AuthStage.anonymous;
      }
    } finally {
      if (_isCurrent(generation)) _setBusy(false);
    }
  }

  void _applyStageFromSession(SessionInfo s) {
    _stage = resolveAuthStage(s);
  }

  /// Google 로그인 플로우.
  Future<void> loginWithGoogle() async {
    if (_isBusy || _disposed) return;
    final generation = ++_generation;
    _setBusy(true);
    _errorMessage = null;
    try {
      await _ensureGoogleInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw StateError('이 플랫폼은 Google 로그인을 지원하지 않습니다.');
      }
      final account = await GoogleSignIn.instance.authenticate();
      if (!_isCurrent(generation)) return;
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google 인증 토큰을 받지 못했습니다.');
      }
      final result = await _services.auth.loginWithGoogle(idToken);
      if (!_isCurrent(generation)) return;
      _applyBootstrap(result);
      if (result.session != null) {
        unawaited(SessionInfoCache.save(result.session!));
      }
    } on GoogleSignInException catch (e) {
      if (!_isCurrent(generation)) return;
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _errorMessage = '로그인이 취소되었습니다.';
      } else {
        _errorMessage = e.description ?? e.code.toString();
      }
    } on ApiException catch (e) {
      if (!_isCurrent(generation)) return;
      _errorMessage = e.message;
      _applyErrorStage(e);
    } on NetworkException catch (e) {
      if (!_isCurrent(generation)) return;
      _errorMessage = e.message;
    } catch (e) {
      if (!_isCurrent(generation)) return;
      _errorMessage = e.toString();
    } finally {
      if (_isCurrent(generation)) _setBusy(false);
    }
  }

  // Phase 8.2: 관리자 ID/PW 로그인 (loginWithPassword) 제거.
  // 백엔드 ADMIN_ID/ADMIN_PW 환경변수 폐기에 따른 회귀.
  // 관리자 권한은 ADMIN_EMAILS 환경변수에 등록된 Google 이메일에만 부여된다.

  Future<void> logout() async {
    if (_disposed) return;
    final generation = ++_generation;
    _session = null;
    _stage = AuthStage.anonymous;
    _errorMessage = null;
    _setBusy(true);
    try {
      if (_googleInitialized) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {
          // Google 로그아웃 실패는 무시
        }
      }
      await _services.auth.logout();
    } catch (_) {
      // 서버 오류여도 로컬 상태는 비운다
    } finally {
      await SessionInfoCache.clear();
      if (_isCurrent(generation)) _setBusy(false);
    }
  }

  /// 로그인 화면에서 "비회원으로 둘러보기" 진입. 비지속(캐시 기록 없음).
  void enterGuestMode() {
    if (_disposed || (_isBusy && _stage != AuthStage.initializing)) return;
    _generation++;
    _isBusy = false;
    _session = null;
    _stage = AuthStage.guest;
    _errorMessage = null;
    notifyListeners();
  }

  /// 게스트 → 로그인 화면 복귀.
  void exitGuestMode() {
    if (_stage == AuthStage.guest) {
      _generation++;
      _stage = AuthStage.anonymous;
      notifyListeners();
    }
  }

  /// consent 단계 완료 후 호출.
  Future<void> markConsentRecorded() async {
    if (_stage == AuthStage.needsConsent) await bootstrap();
  }

  void _applyBootstrap(AuthBootstrap bootstrap) {
    _session = bootstrap.session;
    _stage = resolveAuthStage(_session,
        needsConsent: bootstrap.needsConsent,
        needsPhotoVerification: bootstrap.needsPhotoVerification);
    notifyListeners();
  }

  /// Reflect authoritative session restrictions without treating ordinary 403s
  /// or transport failures as account removal.
  bool handleApiError(ApiException error) {
    if (_disposed) return false;
    final next = error.isAuthRequired
        ? AuthStage.anonymous
        : resolveAuthErrorStage(error, _stage);
    if (!error.isAuthRequired && next == _stage) return false;
    _generation++;
    _stage = next;
    _isBusy = false;
    _errorMessage = error.message;
    if (error.isAuthRequired) {
      _session = null;
      unawaited(ApiClient.instance.clearSession());
    }
    unawaited(SessionInfoCache.clear());
    notifyListeners();
    return true;
  }

  void _applyErrorStage(ApiException e) {
    _stage = resolveAuthErrorStage(e, _stage);
    notifyListeners();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

AuthStage resolveAuthErrorStage(ApiException error, AuthStage current) {
  if ([
    AuthStatus.withdrawn,
    AuthStatus.rejected,
    AuthStatus.blocked,
    AuthStatus.dormant
  ].contains(error.authStatus)) {
    return AuthStage.blocked;
  }
  if (error.needsConsent) return AuthStage.needsConsent;
  if (error.needsProfileSetup) return AuthStage.needsProfileSetup;
  if (error.needsPhotoVerification) return AuthStage.needsPhotoVerification;
  if (error.authStatus == AuthStatus.pending) return AuthStage.pending;
  return current;
}

AuthStage resolveAuthStage(
  SessionInfo? session, {
  bool needsConsent = false,
  bool needsPhotoVerification = false,
}) {
  if (session == null) return AuthStage.anonymous;
  if ([
    AuthStatus.blocked,
    AuthStatus.rejected,
    AuthStatus.withdrawn,
    AuthStatus.dormant
  ].contains(session.status)) {
    return AuthStage.blocked;
  }
  if (needsConsent || session.needsConsent) return AuthStage.needsConsent;
  if (!session.profileComplete) return AuthStage.needsProfileSetup;
  if (needsPhotoVerification) return AuthStage.needsPhotoVerification;
  if (session.status == AuthStatus.pending) return AuthStage.pending;
  if (session.isAdmin) return AuthStage.admin;
  return session.approved ? AuthStage.approved : AuthStage.blocked;
}
