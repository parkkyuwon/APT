import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/core/indoor_location_bridge.dart';
import 'package:apt_ev_charging/models/home_area.dart';
import 'package:apt_ev_charging/models/published_indoor_dataset.dart';
import 'package:apt_ev_charging/models/session.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/providers/indoor_dataset_provider.dart';
import 'package:apt_ev_charging/services/home_area_store.dart';
import 'package:apt_ev_charging/services/indoor_access_controller.dart';
import 'package:apt_ev_charging/services/indoor_positioning_api.dart';
import 'package:apt_ev_charging/services/indoor_survey_store.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  AuthStage stage = AuthStage.approved;
  @override
  SessionInfo? get session => stage == AuthStage.approved
      ? SessionInfo.fromJson({
          'email': 'resident',
          'role': 'user',
          'approved': true,
          'status': 'approved'
        })
      : null;
  @override
  bool get isAdmin => false;
  void logoutForTest() {
    stage = AuthStage.anonymous;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api implements IndoorPositioningApi {
  PublishedIndoorDataset next =
      PublishedIndoorDataset(revision: 1, enabled: true, surveys: []);
  @override
  Future<PublishedIndoorDataset> fetch() async => next;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cache extends IndoorSurveyStore {
  @override
  Future<Map<String, dynamic>?> loadPublished(String scope) async => null;
  @override
  Future<void> savePublished(String scope, Map<String, dynamic> data) async {}
}

class _AreaStore extends HomeAreaStore {
  Completer<HomeArea?>? pending;
  @override
  Future<HomeArea?> load(String scope) async => pending != null
      ? await pending!.future
      : HomeArea(
          accountScope: scope, latitude: 37, longitude: 127, enabled: true);
}

class _Bridge extends IndoorLocationBridge {
  int configured = 0, disabled = 0;
  @override
  Future<void> configure(HomeArea area) async {
    configured++;
  }

  @override
  Future<void> disable() async {
    disabled++;
  }

  @override
  Future<Map<String, dynamic>?> consumeEntry() async => null;
}

Future<void> _flush() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('logout stops account-scoped native monitoring', () async {
    final auth = _Auth(), api = _Api(), bridge = _Bridge();
    final access = IndoorAccessController(api, auth,
        supported: true,
        bridge: bridge,
        areaStore: _AreaStore(),
        datasetFactory: (scope) =>
            IndoorDatasetProvider(api, cacheScope: scope, store: _Cache()));
    await _flush();
    expect(bridge.configured, greaterThan(0));
    auth.logoutForTest();
    await _flush();
    expect(access.publication, isNull);
    expect(bridge.disabled, greaterThan(0));
    access.dispose();
    auth.dispose();
  });
  test('server disable during pending area load cannot re-enable monitor',
      () async {
    final auth = _Auth(), api = _Api(), bridge = _Bridge();
    final areas = _AreaStore()..pending = Completer<HomeArea?>();
    final access = IndoorAccessController(api, auth,
        supported: true,
        bridge: bridge,
        areaStore: areas,
        datasetFactory: (scope) =>
            IndoorDatasetProvider(api, cacheScope: scope, store: _Cache()));
    await _flush();
    api.next = PublishedIndoorDataset(revision: 2, enabled: false, surveys: []);
    await access.publication!.refresh();
    areas.pending!.complete(HomeArea(
        accountScope: 'resident', latitude: 37, longitude: 127, enabled: true));
    await _flush();
    expect(bridge.configured, 0);
    expect(bridge.disabled, greaterThan(0));
    access.dispose();
    auth.dispose();
  });
}
