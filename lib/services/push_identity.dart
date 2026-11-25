int? departureRequestId(Map<String, dynamic> data) {
  if (data['type'] != 'departure_request') return null;
  final id = int.tryParse('${data['requestId']}');
  return id != null && id > 0 ? id : null;
}

Future<bool> resetPushRegistration(
    {required Future<void> Function() clearNotifications,
    required Future<void> Function() disableAutoInit,
    required Future<void> Function() deleteToken}) async {
  var success = true;
  for (final action in [clearNotifications, disableAutoInit, deleteToken]) {
    try {
      await action();
    } catch (_) {
      success = false;
    }
  }
  return success;
}

Future<String?> waitForApnsToken(
    {required Future<String?> Function() read,
    required bool Function() isCurrent,
    required Future<void> Function() delay}) async {
  for (var attempt = 0; attempt < 20 && isCurrent(); attempt++) {
    final token = await read();
    if (!isCurrent()) return null;
    if (token != null) return token;
    await delay();
  }
  return null;
}

/// 늦은 기기 토큰 조회/등록 응답이 다음 계정에 반영되지 않도록 한다.
class PushIdentity {
  String? account;
  int _generation = 0;
  bool registered = false;

  void setAccount(String? value) {
    if (account == value) return;
    account = value;
    _generation++;
    registered = false;
  }

  Future<void> bind(String value,
      {required Future<String?> Function() obtainToken,
      required Future<void> Function(String) register}) async {
    setAccount(value);
    final generation = _generation;
    final token = await obtainToken();
    if (generation != _generation || token == null || token.isEmpty) return;
    await register(token);
    if (generation == _generation) registered = true;
  }
}
