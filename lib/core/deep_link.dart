import 'dart:ui';

/// Android VIEW 인텐트로 앱이 실행되면 Flutter Engine 이 URI 의 path+query 를
/// `PlatformDispatcher.defaultRouteName` 에 넣어준다. 정상 실행 시엔 '/' 가 들어옴.
///
/// 사용 흐름:
///  1) main() 에서 [DeepLink.captureInitial()] 호출 → pendingSlotId 저장
///  2) ShellScreen mount 시 [DeepLink.consumePendingSlot()] 으로 한 번 꺼냄
///  3) HomeScreen 이 해당 슬롯의 다이얼로그를 자동으로 띄움
class DeepLink {
  DeepLink._();

  static String? _pendingSlotId;

  /// 앱 시작 직후 한 번 호출. 초기 라우트를 분석해 ?slot=<id> 를 추출.
  static void captureInitial() {
    final raw = PlatformDispatcher.instance.defaultRouteName;
    final extracted = _extractSlotId(raw);
    if (extracted != null) _pendingSlotId = extracted;
  }

  /// 외부 VIEW 인텐트가 지정한 slotId. 한 번 소비하면 null 로 클리어.
  static String? consumePendingSlot() {
    final id = _pendingSlotId;
    _pendingSlotId = null;
    return id;
  }

  /// 외부에서 직접 set 가능 (예: MethodChannel 로 onNewIntent 구현 시).
  static void setPendingSlot(String slotId) {
    _pendingSlotId = slotId;
  }

  /// "/index.html?slot=fast50-1" 같은 문자열에서 slot 값 추출.
  static String? _extractSlotId(String raw) {
    if (raw.isEmpty || raw == '/') return null;
    try {
      // PlatformDispatcher 의 defaultRouteName 은 path+query 가 일반적이라
      // 절대 URI 가 아닐 수 있음. parse 가 실패해도 query 만 추출 가능.
      final qIdx = raw.indexOf('?');
      final query = qIdx >= 0 ? raw.substring(qIdx + 1) : '';
      if (query.isEmpty) return null;
      final params = Uri.splitQueryString(query);
      final slot = params['slot']?.trim();
      return (slot == null || slot.isEmpty) ? null : slot;
    } catch (_) {
      return null;
    }
  }
}
