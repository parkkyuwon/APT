/// Fake members for computer-use validation. All addresses use .invalid;
/// this fixture never accesses a server or sends push notifications.
class LocalMemberManagement {
  LocalMemberManagement(String selfEmail) {
    final now = DateTime.now().toUtc();
    Map<String, dynamic> user(String email, String name,
            {bool incomplete = false,
            bool admin = false,
            bool active = false,
            int days = 100,
            bool neverUsed = false}) =>
        {
          'email': email,
          'name': name,
          'nickname': incomplete ? '' : '$name 별명',
          'vehicleNumber': incomplete ? '' : '12가3456',
          'profileComplete': !incomplete,
          'role': admin ? 'admin' : 'user',
          'status': 'approved',
          'vehicleVerified': !incomplete,
          'ocrMatched': !incomplete,
          'vehicleSubmissionVersion': incomplete ? 0 : 1,
          'consentAt': now.toIso8601String(),
          'createdAt':
              now.subtract(Duration(days: days + 10)).toIso8601String(),
          'lastUsedAt': neverUsed
              ? null
              : now.subtract(Duration(days: days)).toIso8601String(),
          'activeParking': active,
        };
    _users.addAll([
      user(selfEmail, '테스트 관리자', admin: true),
      user('incomplete-one@example.invalid', '미입력 회원 1', incomplete: true),
      user('incomplete-two@example.invalid', '미입력 회원 2',
          incomplete: true, neverUsed: true),
      user('old-member@example.invalid', '장기 미사용 회원', days: 200),
      user('recent-member@example.invalid', '최근 사용 회원', days: 1),
      user('active-member@example.invalid', '현재 주차 회원', active: true),
    ]);
  }
  final List<Map<String, dynamic>> _users = [];
  final Map<String, List<Map<String, dynamic>>> _notices = {};

  Map<String, dynamic> list(Map<String, String> query) {
    final amount = int.tryParse(query['inactiveValue'] ?? '');
    final now = DateTime.now().toUtc();
    DateTime? cutoff;
    if (amount != null) {
      if (query['inactiveUnit'] == 'months') {
        final first = DateTime.utc(now.year, now.month - amount);
        final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
        cutoff = DateTime.utc(
            first.year,
            first.month,
            now.day > lastDay ? lastDay : now.day,
            now.hour,
            now.minute,
            now.second);
      } else {
        cutoff = now.subtract(Duration(days: amount));
      }
    }
    final users = _users.where((user) {
      if (query['incompleteOnly'] == 'true' &&
          user['profileComplete'] == true) {
        return false;
      }
      if (cutoff != null) {
        if (user['activeParking'] == true) return false;
        final used =
            DateTime.parse((user['lastUsedAt'] ?? user['createdAt']) as String);
        if (used.isAfter(cutoff)) return false;
      }
      return true;
    });
    return {
      'ok': true,
      'users': users
          .skip(int.tryParse(query['offset'] ?? '') ?? 0)
          .take(int.tryParse(query['limit'] ?? '') ?? 100)
          .toList()
    };
  }

  Map<String, dynamic> mutate(String method, Map<String, dynamic> body) {
    final raw = body['emails'];
    if (raw is! List || raw.isEmpty || raw.length > 100) return _error();
    final emails = raw.map((email) => '$email'.trim().toLowerCase()).toSet();
    final selected =
        _users.where((user) => emails.contains(user['email'])).toList();
    if (selected.length != emails.length ||
        selected.any((u) => u['role'] == 'admin')) {
      return _error();
    }
    if (method == 'DELETE') {
      _users.removeWhere((user) => emails.contains(user['email']));
      for (final email in emails) {
        _notices.remove(email);
      }
      return {'ok': true, 'deletedCount': selected.length};
    }
    if (method == 'POST' && body['action'] == 'clear-personal-data') {
      for (final user in selected) {
        user.remove('phoneNumber');
        user.remove('vehiclePhoto');
        if (user['vehicleVerified'] != true) {
          user['ocrMatched'] = false;
          user['profileComplete'] = false;
          user['vehicleSubmissionVersion'] =
              (user['vehicleSubmissionVersion'] as int) + 1;
        }
      }
      return {'ok': true, 'clearedCount': selected.length};
    }
    if (method != 'POST' ||
        body['action'] != 'request-profile' ||
        selected.any((u) => u['profileComplete'] == true)) {
      return _error();
    }
    final custom = '${body['message'] ?? ''}'.trim();
    if (custom.length > 2000) return _error();
    const base = '닉네임과 차량번호 한 개를 입력하고 번호판 사진 비교를 완료해 주세요.';
    for (final email in emails) {
      final notices = _notices.putIfAbsent(email, () => []);
      notices.insert(0, {
        'id': '${notices.length + 1}',
        'message': custom.isEmpty ? base : '$base\n\n$custom',
        'createdAt': DateTime.now().toUtc().toIso8601String()
      });
    }
    return {
      'ok': true,
      'sentCount': selected.length,
      'pushSentCount': 0,
      'pushFailedCount': 0
    };
  }

  Map<String, dynamic> notices(String email) =>
      {'ok': true, 'notices': _notices[email] ?? []};
  Map<String, dynamic> _error() =>
      {'ok': false, 'error': '유효하지 않은 회원 선택 또는 작업입니다.'};
}
