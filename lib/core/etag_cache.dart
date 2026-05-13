/// ETag 지원 엔드포인트용 메모리 캐시.
///
/// 영속화는 stale 위험이 커서 의도적으로 메모리 한정. 콜드 스타트 첫 요청은
/// ETag 없이 200 으로 받고, 같은 세션 내 후속 요청에서만 304 적중을 노린다.
class EtagCache {
  EtagCache({int maxEntries = 32}) : _maxEntries = maxEntries;

  final int _maxEntries;
  final Map<String, _Entry> _entries = <String, _Entry>{};

  String? getEtag(String key) => _entries[key]?.etag;
  dynamic getBody(String key) => _entries[key]?.body;

  void store({required String key, required String etag, required dynamic body}) {
    if (_entries.length >= _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = _Entry(etag: etag, body: body);
  }

  void invalidate(String key) => _entries.remove(key);
  void clear() => _entries.clear();
}

class _Entry {
  _Entry({required this.etag, required this.body});
  final String etag;
  final dynamic body;
}
