import 'package:flutter/foundation.dart';

/// 외부 OS 단의 connectivity 추적은 Gradle 빌드 의존성을 무겁게 만들어 직접 측정 대신
/// API 호출 결과를 기반으로 오프라인 상태를 추정한다.
///
/// - 모든 ApiClient 호출이 NetworkException 으로 실패하면 `markOffline()` 호출.
/// - 어느 호출이든 성공하면 `markOnline()` 호출.
/// - 두 번 연속 실패해야 오프라인으로 판단해 일시 오류로 인한 false-positive 회피.
class ConnectivityProvider extends ChangeNotifier {
  bool _isOffline = false;
  int _consecutiveFailures = 0;

  bool get isOffline => _isOffline;

  void markOffline() {
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= 2 && !_isOffline) {
      _isOffline = true;
      notifyListeners();
    }
  }

  void markOnline() {
    _consecutiveFailures = 0;
    if (_isOffline) {
      _isOffline = false;
      notifyListeners();
    }
  }
}
