import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:apt_ev_charging/core/indoor_location_bridge.dart';
import 'package:apt_ev_charging/models/home_area.dart';
import 'package:apt_ev_charging/services/home_area_store.dart';
import 'package:apt_ev_charging/screens/public/home_area_settings_screen.dart';

class FakeBridge extends IndoorLocationBridge {
  int disabled = 0;
  String? disabledScope;
  @override
  Future<void> disableForAccount(String accountScope) async {
    disabledScope = accountScope;
    await disable();
  }

  @override
  Future<IndoorLocationStatus> status() async =>
      const IndoorLocationStatus(reason: 'permissionRequired', supported: true);
  @override
  Future<void> disable() async {
    disabled++;
  }
}

class PendingDeleteStore extends HomeAreaStore {
  final deleted = Completer<void>();
  @override
  Future<void> delete(String accountScope) => deleted.future;
}

class SettingsBridge extends FakeBridge {
  final opened = <String>[];
  IndoorLocationStatus reported = const IndoorLocationStatus(supported: true);
  int configurations = 0;
  @override
  Future<IndoorLocationStatus> status() async => reported;
  @override
  Future<void> configure(HomeArea area) async {
    configurations++;
  }

  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> requestBackgroundPermission() async {}
  @override
  Future<bool> openSettings(String target) async {
    opened.add(target);
    return true;
  }
}

class PendingPermissionBridge extends FakeBridge {
  final permission = Completer<void>();
  int configurations = 0;
  @override
  Future<void> requestPermissions() => permission.future;
  @override
  Future<void> requestBackgroundPermission() async {}
  @override
  Future<void> configure(HomeArea area) async {
    configurations++;
  }

  @override
  Future<IndoorLocationStatus> status() async => const IndoorLocationStatus(
      supported: true,
      locationAllowed: true,
      backgroundAllowed: true,
      notificationAllowed: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('coordinates show an OSM marker and a metric radius',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: HomeAreaSettingsScreen(accountScope: 'a', bridge: FakeBridge())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('home-latitude')), '37.5');
    await tester.enterText(find.byKey(const Key('home-longitude')), '127.1');
    await tester.pump();
    expect(find.byKey(const Key('home-area-map')), findsOneWidget);
    final marker =
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single;
    expect(marker.point.latitude, 37.5);
    expect(marker.point.longitude, 127.1);
    final circle =
        tester.widget<CircleLayer>(find.byType(CircleLayer)).circles.single;
    expect(circle.radius, 200);
    expect(circle.useRadiusInMeter, isTrue);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(1000);
    await tester.pump();
    expect(
        tester
            .widget<CircleLayer>(find.byType(CircleLayer))
            .circles
            .single
            .radius,
        1000);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'missing precise location offers settings and cancel never opens them',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'requestPermissions'
                ? {for (final id in call.arguments as List) id: 1}
                : 1);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final store = HomeAreaStore();
    await store.save(HomeArea(accountScope: 'a', latitude: 37, longitude: 127));
    final bridge = SettingsBridge();
    await tester.pumpWidget(MaterialApp(
        home: HomeAreaSettingsScreen(
            accountScope: 'a',
            store: store,
            bridge: bridge,
            serviceEnabled: () => true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(SwitchListTile), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('background-location-continue')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('home-settings-dialog')), findsOneWidget);
    expect(find.text('정확한 위치 허용'), findsOneWidget);
    expect(bridge.opened, isEmpty);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(bridge.opened, isEmpty);
    expect((await store.load('a'))!.enabled, isFalse);
  });
  for (final disableAdmin in [false, true]) {
    testWidgets(
        'settings return respects grants and admin disabled=$disableAdmin',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              channel,
              (call) async => call.method == 'requestPermissions'
                  ? {for (final id in call.arguments as List) id: 1}
                  : 1);
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final store = HomeAreaStore();
      await store
          .save(HomeArea(accountScope: 'a', latitude: 37, longitude: 127));
      final bridge = SettingsBridge()
        ..reported = const IndoorLocationStatus(
            supported: true, locationAllowed: true, notificationAllowed: true);
      var enabled = true;
      await tester.pumpWidget(MaterialApp(
          home: HomeAreaSettingsScreen(
              accountScope: 'a',
              store: store,
              bridge: bridge,
              serviceEnabled: () => enabled)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('background-location-continue')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('백그라운드 위치 허용'), findsOneWidget);
      await tester.tap(find.text('설정으로 이동'));
      await tester.pumpAndSettle();
      expect(bridge.opened, ['background']);
      expect(bridge.configurations, 0);
      bridge.reported = const IndoorLocationStatus(
          supported: true,
          locationAllowed: true,
          backgroundAllowed: true,
          notificationAllowed: true);
      enabled = !disableAdmin;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(bridge.configurations, disableAdmin ? 0 : 1);
      expect((await store.load('a'))!.enabled, !disableAdmin);
      expect(bridge.opened, ['background']);
    });
  }
  testWidgets(
      'background disclosure precedes permissions and cancellation does not request them',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var permissionRequests = 0;
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      permissionRequests++;
      return {for (final id in call.arguments as List) id: 1};
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final store = HomeAreaStore();
    await store.save(HomeArea(accountScope: 'a', latitude: 37, longitude: 127));
    await tester.pumpWidget(MaterialApp(
        home: HomeAreaSettingsScreen(
            accountScope: 'a',
            store: store,
            bridge: FakeBridge(),
            serviceEnabled: () => true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(SwitchListTile), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(find.byKey(const Key('background-location-disclosure')),
        findsOneWidget);
    expect(find.textContaining('앱이 닫혀 있거나 사용 중이 아닐 때도'), findsOneWidget);
    expect(permissionRequests, 0);
    await tester.tap(find.byKey(const Key('background-location-later')));
    await tester.pumpAndSettle();
    expect(permissionRequests, 0);
    expect((await store.load('a'))!.enabled, isFalse);
  });
  testWidgets('admin disabling during permission prompt prevents activation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'requestPermissions') {
        return {for (final id in call.arguments as List) id: 1};
      }
      return 1;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final store = HomeAreaStore();
    final bridge = PendingPermissionBridge();
    var enabled = true;
    await store.save(HomeArea(accountScope: 'a', latitude: 37, longitude: 127));
    await tester.pumpWidget(MaterialApp(
        home: HomeAreaSettingsScreen(
            accountScope: 'a',
            store: store,
            bridge: bridge,
            serviceEnabled: () => enabled)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(SwitchListTile), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.tap(find.byKey(const Key('background-location-continue')));
    await tester.pump();
    await tester.pump();
    enabled = false;
    bridge.permission.complete();
    await tester.pumpAndSettle();
    expect(bridge.configurations, 0);
    expect((await store.load('a'))!.enabled, isFalse);
  });
  testWidgets(
      'leaving screen while deletion completes never touches disposed fields',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = PendingDeleteStore();
    await store.save(HomeArea(accountScope: 'a', latitude: 37, longitude: 127));
    await tester.pumpWidget(MaterialApp(
        home: HomeAreaSettingsScreen(
            accountScope: 'a', store: store, bridge: FakeBridge())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('집 설정 삭제'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('집 설정 삭제'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    store.deleted.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('manual setup saves without requesting monitoring and deletes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = HomeAreaStore();
    final bridge = FakeBridge();
    await tester.pumpWidget(MaterialApp(
        home: HomeAreaSettingsScreen(
            accountScope: 'a', store: store, bridge: bridge)));
    await tester.pumpAndSettle();
    expect(find.textContaining('지도에서 집 위치를 선택'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('home-latitude')), '37.5');
    await tester.enterText(find.byKey(const Key('home-longitude')), '127.1');
    await tester.pump();
    await tester.ensureVisible(find.text('설정 저장'));
    await tester.tap(find.text('설정 저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('집 반경을 저장했습니다'), findsOneWidget);
    expect((await store.load('a'))!.enabled, isFalse);
    await tester.scrollUntilVisible(find.text('집 설정 삭제'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('집 설정 삭제'));
    await tester.pumpAndSettle();
    expect(await store.load('a'), isNull);
  });
  testWidgets('loads stored home and never starts observation automatically',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = HomeAreaStore();
    await store.save(HomeArea(
        accountScope: 'a', latitude: 37, longitude: 127, enabled: true));
    await tester.pumpWidget(MaterialApp(
        home: HomeAreaSettingsScreen(
            accountScope: 'a', store: store, bridge: FakeBridge())));
    await tester.pumpAndSettle();
    expect(find.text('37.0'), findsOneWidget);
    expect(find.textContaining('감시 중지 상태'), findsOneWidget);
  });
}
