import 'dart:async';
import 'dart:convert';

import 'package:apt_ev_charging/config/app_config.dart';
import 'package:apt_ev_charging/core/state_cache.dart';
import 'package:apt_ev_charging/models/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The plugin's platform seam lets this test delay a real preference write.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppConfig.init();
    await StateCache.clear();
  });

  test('restores state only for its original member', () async {
    final state = AppState.fromJson({'maintenanceMode': true});
    await StateCache.save(state, owner: 'alice@example.test');
    expect(StateCache.load(owner: 'alice@example.test')?.maintenanceMode, true);
    expect(StateCache.load(owner: 'bob@example.test'), isNull);
  });

  test('voice registration identity and preference survive owner scoped cache',
      () async {
    final state = AppState.fromJson({
      'slotDetails': {
        'fast50-1': {
          'vehicleNumber': '123가4567',
          'parkingRegistrationId': 'opaque-cache',
          'callAllowed': true,
        }
      }
    });
    await StateCache.save(state, owner: 'owner@example.invalid');
    final detail = StateCache.load(owner: 'owner@example.invalid')
        ?.slotDetails['fast50-1'];
    expect(detail?.parkingRegistrationId, 'opaque-cache');
    expect(detail?.callAllowed, isTrue);
    expect(StateCache.load(owner: 'other@example.invalid'), isNull);
  });

  test('legacy cache without an owner cannot be restored for a member',
      () async {
    await AppConfig.prefs.setString(
      'app_state_v1',
      jsonEncode(AppState.empty().toJson()),
    );
    // A separately saved owner cannot authenticate an old payload atomically.
    await AppConfig.prefs.setString('app_state_owner_v1', 'alice@example.test');
    expect(StateCache.load(owner: 'alice@example.test'), isNull);
    expect(StateCache.load(), isNotNull);
  });

  test('clear cannot be overtaken by an already started cache save', () async {
    final save = StateCache.save(AppState.empty(), owner: 'alice@example.test');
    final clear = StateCache.clear();
    await Future.wait([save, clear]);
    expect(StateCache.load(), isNull);
    expect(StateCache.cachedAt(), isNull);
  });

  test('a pending new owner write cannot expose its state to the old owner',
      () async {
    final store = _DelayedStore();
    SharedPreferencesStorePlatform.instance = store;
    await StateCache.save(AppState.empty(), owner: 'alice@example.test');
    store.delayState = true;
    final save = StateCache.save(
      AppState.fromJson({'maintenanceMode': true}),
      owner: 'bob@example.test',
    );
    await store.started.future;
    try {
      expect(StateCache.load(owner: 'alice@example.test'), isNull);
    } finally {
      store.release.complete();
      await save;
    }
    expect(StateCache.load(owner: 'bob@example.test')?.maintenanceMode, true);
  });
}

class _DelayedStore extends InMemorySharedPreferencesStore {
  _DelayedStore() : super.empty();

  bool delayState = false;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (delayState && key == 'flutter.app_state_v1') {
      started.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}
