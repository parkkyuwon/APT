import 'package:apt_ev_charging/core/bluetooth_permissions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sdkChannel = MethodChannel('apt_ev/bluetooth_permissions');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sdkChannel, null);
  });

  test('iOS requests and requires Bluetooth without location permissions', () {
    expect(bluetoothPermissionsFor(TargetPlatform.iOS), [Permission.bluetooth]);
    expect(
      bluetoothPermissionsGranted(TargetPlatform.iOS, {
        Permission.bluetooth: PermissionStatus.granted,
        Permission.locationWhenInUse: PermissionStatus.denied,
      }),
      isTrue,
    );
    expect(
      bluetoothPermissionsGranted(TargetPlatform.iOS, {
        Permission.bluetooth: PermissionStatus.denied,
        Permission.locationWhenInUse: PermissionStatus.granted,
      }),
      isFalse,
    );
  });

  test('Android 12 and newer request scan, connect, and location', () {
    expect(
      bluetoothPermissionsFor(TargetPlatform.android, androidSdkInt: 31),
      [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ],
    );
    expect(
      bluetoothPermissionsFor(TargetPlatform.android, androidSdkInt: 35),
      [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ],
    );
  });

  test('Android 12 and newer require location with Bluetooth grants', () {
    expect(
      bluetoothPermissionsGranted(
        TargetPlatform.android,
        {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
        androidSdkInt: 31,
      ),
      isFalse,
    );
    expect(
      bluetoothPermissionsGranted(
        TargetPlatform.android,
        {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.granted,
        },
        androidSdkInt: 31,
      ),
      isTrue,
    );
  });

  test('Android 11 and older request and require location only', () {
    expect(
      bluetoothPermissionsFor(TargetPlatform.android, androidSdkInt: 30),
      [Permission.locationWhenInUse],
    );
    expect(
      bluetoothPermissionsGranted(
        TargetPlatform.android,
        {Permission.locationWhenInUse: PermissionStatus.granted},
        androidSdkInt: 30,
      ),
      isTrue,
    );
    expect(
      bluetoothPermissionsGranted(
        TargetPlatform.android,
        {
          Permission.locationWhenInUse: PermissionStatus.granted,
          Permission.bluetoothScan: PermissionStatus.denied,
        },
        androidSdkInt: 30,
      ),
      isTrue,
    );
  });

  test('unknown Android SDK requests and requires every permission', () {
    expect(
      bluetoothPermissionsFor(TargetPlatform.android),
      [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ],
    );
    expect(
      bluetoothPermissionsGranted(
        TargetPlatform.android,
        {
          Permission.bluetoothScan: PermissionStatus.granted,
          Permission.bluetoothConnect: PermissionStatus.granted,
          Permission.locationWhenInUse: PermissionStatus.denied,
        },
      ),
      isFalse,
    );
  });

  test('reads Android SDK level from the native method channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sdkChannel, (call) async {
      expect(call.method, 'getAndroidSdkInt');
      return 35;
    });

    expect(await queryAndroidSdkInt(), 35);
  });

  test('unsupported native SDK query returns unknown', () async {
    expect(await queryAndroidSdkInt(), isNull);
  });
}
