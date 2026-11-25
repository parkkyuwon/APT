import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:apt_ev_charging/models/home_area.dart';
import 'package:apt_ev_charging/services/home_area_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('secure home area persists separately for each account and deletes',
      () async {
    final store = HomeAreaStore();
    await store.save(HomeArea(accountScope: 'a', latitude: 37, longitude: 127));
    expect((await store.load('a'))!.radiusMeters, 200);
    expect(await store.load('b'), isNull);
    await store.delete('a');
    expect(await store.load('a'), isNull);
  });
  test('rejects invalid coordinates and radius', () {
    expect(() => HomeArea(accountScope: 'a', latitude: 91, longitude: 0),
        throwsArgumentError);
    expect(
        () => HomeArea(
            accountScope: 'a', latitude: 0, longitude: 0, radiusMeters: 99),
        throwsArgumentError);
  });
}
