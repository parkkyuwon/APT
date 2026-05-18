import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'errors.dart';
import 'etag_cache.dart';
import 'json_utils.dart';
import 'session_store.dart';

/// 앱 전체에서 공유되는 Dio 인스턴스.
///
/// - 세션 쿠키를 Keystore/Keychain 에 영속화 ([SecureCookieJar])
/// - /api/state 등 ETag 지원 엔드포인트에 If-None-Match 자동 첨부
/// - 서버의 { ok: false, error, authStatus, ... } 응답을 [ApiException] 으로 변환
class ApiClient {
  ApiClient._(this._dio, this._cookieJar, this._etagCache);

  final Dio _dio;
  final SecureCookieJar _cookieJar;
  final EtagCache _etagCache;

  static ApiClient? _instance;

  static ApiClient get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('ApiClient 가 초기화되지 않았습니다. ApiClient.init() 을 먼저 호출하세요.');
    }
    return i;
  }

  static Future<ApiClient> init() async {
    if (_instance != null) return _instance!;

    final jar = SecureCookieJar(storage: AppConfig.secureStorage);
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        sendTimeout: AppConfig.apiTimeout,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Phase 8.5: Flutter 앱 식별. 백엔드 requireSafeOrigin 통과용.
          'X-App-Client': 'apt-ev-flutter',
        },
        responseType: ResponseType.json,
        // 200/304/4xx 모두 interceptor 에서 직접 해석
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(_RetryInterceptor(dio));
    final etag = EtagCache();
    dio.interceptors.add(_EtagInterceptor(etag));

    if (kDebugMode) {
      dio.interceptors.add(_DebugInterceptor());
    }

    final client = ApiClient._(dio, jar, etag);
    _instance = client;
    return client;
  }

  Dio get dio => _dio;
  SecureCookieJar get cookieJar => _cookieJar;
  EtagCache get etagCache => _etagCache;

  Future<void> clearSession() async {
    await _cookieJar.deleteAll();
    _etagCache.clear();
  }

  /// 응답 본문을 { ok: true, ... } 로 검증하고, 실패 시 [ApiException] 을 던진다.
  Future<Map<String, dynamic>> requireOk(Response<dynamic> response) async {
    final raw = response.data;
    if (raw is! Map) {
      throw ApiException(
        statusCode: response.statusCode ?? -1,
        message: 'Unexpected response format',
      );
    }
    final body = Map<String, dynamic>.from(raw);
    final ok = body['ok'] == true;
    final status = response.statusCode ?? -1;

    if (!ok || status >= 400) {
      throw ApiException(
        statusCode: status,
        message: stringifyError(body['error']) ?? '요청을 처리할 수 없습니다.',
        authStatus: authStatusFromString(asStrOrNull(body['authStatus'])),
        needsConsent: asBool(body['needsConsent']),
        needsProfileSetup: asBool(body['needsProfileSetup']),
        needsPhotoVerification: asBool(body['needsPhotoVerification']),
        missing: asListOf<String>(body['missing']),
        rawBody: body,
      );
    }

    return body;
  }

  /// DioException 을 [NetworkException] 또는 [ApiException] 으로 일원화.
  Never rethrowAsApp(DioException error) {
    final response = error.response;
    if (response != null) {
      // 서버가 응답했지만 4xx 인 경우 — 본문을 ApiException 으로 변환
      final body = response.data;
      if (body is Map) {
        throw ApiException(
          statusCode: response.statusCode ?? -1,
          message: stringifyError(body['error']) ?? error.message ?? 'Unknown error',
          authStatus: authStatusFromString(asStrOrNull(body['authStatus'])),
          needsConsent: asBool(body['needsConsent']),
          needsProfileSetup: asBool(body['needsProfileSetup']),
          needsPhotoVerification: asBool(body['needsPhotoVerification']),
          rawBody: Map<String, dynamic>.from(body),
        );
      }
    }
    throw NetworkException(error.message ?? '네트워크 오류', error);
  }
}

/// ETag 인터셉터 — GET 요청 중 특정 경로에 자동으로 If-None-Match 를 붙인다.
class _EtagInterceptor extends Interceptor {
  _EtagInterceptor(this._cache);
  final EtagCache _cache;

  static const _eligiblePaths = <String>{'/api/state', '/api/public-dashboard', '/api/public-highlight'};

  bool _isEligible(String path) => _eligiblePaths.any(path.endsWith);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() == 'GET' && _isEligible(options.path)) {
      final etag = _cache.getEtag(options.path);
      if (etag != null) {
        options.headers['If-None-Match'] = etag;
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    if (options.method.toUpperCase() == 'GET' && _isEligible(options.path)) {
      final status = response.statusCode;
      if (status == 304) {
        final cached = _cache.getBody(options.path);
        if (cached != null) {
          response
            ..data = cached
            ..statusCode = 200;
        }
      } else if (status == 200) {
        final etag = response.headers.value('etag');
        if (etag != null && response.data != null) {
          _cache.store(key: options.path, etag: etag, body: response.data);
        }
      }
    }
    handler.next(response);
  }
}

/// 일시적 네트워크 오류 발생 시 GET 요청만 1·2초 백오프로 최대 2회 재시도.
/// POST/PUT/DELETE 는 멱등성 보장 어려워 재시도 안 함.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);
  final Dio _dio;

  static const _maxRetries = 2;
  static const _backoffs = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  bool _isRetriable(DioException err) {
    if (err.requestOptions.method.toUpperCase() != 'GET') return false;
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // DNS 실패 등 네트워크 문제 다수가 unknown 으로 분류됨
        return err.error != null;
      default:
        return false;
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['retry_attempt'] as int?) ?? 0;
    if (!_isRetriable(err) || attempt >= _maxRetries) {
      handler.next(err);
      return;
    }
    await Future<void>.delayed(_backoffs[attempt]);
    final newOptions = err.requestOptions.copyWith(
      extra: {...err.requestOptions.extra, 'retry_attempt': attempt + 1},
    );
    try {
      final response = await _dio.fetch<dynamic>(newOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

class _DebugInterceptor extends Interceptor {
  /// 로그에 포함되면 PII 노출 위험인 쿼리 키.
  static const _sensitiveKeys = <String>{
    'email',
    'phone',
    'phoneNumber',
    'phone_number',
    'vehicle',
    'vehicleNumber',
    'vehicle_number',
    'token',
    'idToken',
    'id_token',
    'password',
  };

  String _safeUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri.toString();
    final masked = <String, String>{};
    uri.queryParameters.forEach((k, v) {
      masked[k] = _sensitiveKeys.contains(k) ? '***' : v;
    });
    return uri.replace(queryParameters: masked).toString();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API] ${options.method} ${_safeUri(options.uri)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
          '[API] ${response.statusCode} ${_safeUri(response.requestOptions.uri)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
          '[API!] ${err.response?.statusCode} ${_safeUri(err.requestOptions.uri)} — ${err.message}');
    }
    handler.next(err);
  }
}
