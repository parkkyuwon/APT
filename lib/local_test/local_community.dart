/// Memory-only community fixture. Never forwards an unsupported request.
class LocalCommunity {
  LocalCommunity(this.email, {required this.admin});
  final String email;
  final bool admin;
  final List<Map<String, dynamic>> _posts = [];
  final List<Map<String, dynamic>> _reports = [];
  int _nextPost = 1;
  int _nextReport = 1;

  Map<String, dynamic>? handle(String method, String path,
      Map<String, String> query, Map<String, dynamic> body) {
    if (path != '/api/board' && path != '/api/charger-reports') return null;
    final board = path == '/api/board';
    final records = board ? _posts : _reports;
    final id = int.tryParse('${body['id'] ?? query['id'] ?? ''}');
    final matching = records.where((item) => item['id'] == id);
    if (method == 'GET') {
      if (!board && id != null) {
        if (matching.isEmpty) return _error();
        return {'ok': true, 'report': Map.of(matching.first)};
      }
      final before = int.tryParse(query['before'] ?? '');
      return {
        'ok': true,
        board ? 'posts' : 'reports': records.reversed
            .where((item) => before == null || (item['id'] as int) < before)
            .take(50)
            .map((item) => Map<String, dynamic>.of(item))
            .toList(),
      };
    }
    if (method == 'POST') {
      final title = '${body['title'] ?? ''}'.trim();
      final content = '${body['content'] ?? ''}'.trim();
      final description = '${body['description'] ?? ''}'.trim();
      if (board &&
          (title.isEmpty ||
              title.length > 120 ||
              content.isEmpty ||
              content.length > 10000)) {
        return _error();
      }
      if (!board &&
          ('${body['slotId'] ?? ''}'.isEmpty ||
              description.isEmpty ||
              description.length > 4000)) {
        return _error();
      }
      final item = <String, dynamic>{
        'id': board ? _nextPost++ : _nextReport++,
        'authorEmail': email,
        'authorName': '테스트 회원',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        if (board) ...{'title': title, 'content': content},
        if (!board) ...{
          'slotId': body['slotId'],
          'description': description,
          'photo': body['photo'] ?? '',
          'status': 'received'
        },
      };
      records.add(item);
      return {'ok': true, board ? 'post' : 'report': Map.of(item)};
    }
    if (matching.isEmpty) return _error();
    final item = matching.first;
    if (board && method == 'DELETE') {
      records.remove(item);
      return {'ok': true};
    }
    if (board && method == 'PUT') {
      final title = '${body['title'] ?? ''}'.trim();
      final content = '${body['content'] ?? ''}'.trim();
      if (title.isEmpty ||
          title.length > 120 ||
          content.isEmpty ||
          content.length > 10000) {
        return _error();
      }
      item.addAll({'title': title, 'content': content});
      return {'ok': true, 'post': Map.of(item)};
    }
    if (!board &&
        method == 'PATCH' &&
        admin &&
        ['received', 'in_progress', 'resolved'].contains(body['status'])) {
      item['status'] = body['status'];
      return {'ok': true, 'report': Map.of(item)};
    }
    return _error();
  }

  Map<String, dynamic> _error() => {'ok': false, 'error': '잘못된 로컬 테스트 요청입니다.'};
}
