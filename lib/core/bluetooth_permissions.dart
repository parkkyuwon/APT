import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

const _androidSdkChannel = MethodChannel('apt_ev/bluetooth_permissions');

/// Returns Android's API level, or null when the native channel is unavailable.
Future<int?> queryAndroidSdkInt() async {
  try {
    return await _androidSdkChannel.invokeMethod<int>('getAndroidSdkInt');
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

/// Permissions needed for beacon scanning that estimates an indoor location.
///
/// Android 11 and earlier use location permission for BLE scanning. Android 12
/// and newer need nearby-device permissions as well as location. If the SDK
/// level cannot be read, require the full set so location is never omitted.
List<Permission> bluetoothPermissionsFor(
  TargetPlatform platform, {
  int? androidSdkInt,
}) {
  if (platform == TargetPlatform.iOS) return [Permission.bluetooth];
  if (platform == TargetPlatform.android &&
      androidSdkInt != null &&
      androidSdkInt <= 30) {
    return [Permission.locationWhenInUse];
  }
  if (platform == TargetPlatform.android) {
    return [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];
  }
  return const [];
}

bool bluetoothPermissionsGranted(
  TargetPlatform platform,
  Map<Permission, PermissionStatus> results, {
  int? androidSdkInt,
}) {
  bool isOk(Permission? permission) {
    if (permission == null) return false;
    final status = results[permission];
    return status != null &&
        (status.isGranted || status.isLimited || status.isProvisional);
  }

  if (platform == TargetPlatform.iOS) return isOk(Permission.bluetooth);
  if (platform == TargetPlatform.android) {
    if (!isOk(Permission.locationWhenInUse)) return false;
    if (androidSdkInt != null && androidSdkInt <= 30) return true;
    return isOk(Permission.bluetoothScan) && isOk(Permission.bluetoothConnect);
  }
  return false;
}
