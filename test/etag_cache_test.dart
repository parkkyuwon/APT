import 'package:apt_ev_charging/core/etag_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store/get/invalidate', () {
    final cache = EtagCache();
    expect(cache.getEtag('/api/state'), isNull);

    cache.store(key: '/api/state', etag: '"abc"', body: {'hello': 'world'});
    expect(cache.getEtag('/api/state'), '"abc"');
    expect(cache.getBody('/api/state'), {'hello': 'world'});

    cache.invalidate('/api/state');
    expect(cache.getEtag('/api/state'), isNull);
  });

  test('LRU 축출 (maxEntries 초과 시 첫 항목 제거)', () {
    final cache = EtagCache(maxEntries: 2);
    cache.store(key: 'a', etag: '"1"', body: 1);
    cache.store(key: 'b', etag: '"2"', body: 2);
    cache.store(key: 'c', etag: '"3"', body: 3);
    expect(cache.getEtag('a'), isNull);
    expect(cache.getEtag('b'), '"2"');
    expect(cache.getEtag('c'), '"3"');
  });

  test('clear() 모두 제거', () {
    final cache = EtagCache();
    cache.store(key: 'x', etag: '"x"', body: 'body');
    cache.clear();
    expect(cache.getEtag('x'), isNull);
  });
}
