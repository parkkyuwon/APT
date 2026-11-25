import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/home_area.dart';

class IndoorLocationStatus {
  const IndoorLocationStatus(
      {this.supported = false,
      this.monitoring = false,
      this.reason = 'unsupported',
      this.notificationAllowed = false,
      this.locationAllowed = false,
      this.backgroundAllowed = false});
  final bool supported,
      monitoring,
      notificationAllowed,
      locationAllowed,
      backgroundAllowed;
  final String reason;
  factory IndoorLocationStatus.fromMap(Map<dynamic, dynamic> map) =>
      IndoorLocationStatus(
          supported: map['supported'] == true,
          monitoring: map['monitoring'] == true,
          reason: map['reason']?.toString() ?? '',
          notificationAllowed: map['notificationAllowed'] == true,
          locationAllowed: map['locationAllowed'] == true,
          backgroundAllowed: map['backgroundAllowed'] == true);
}

class OutdoorLocationFix {
  const OutdoorLocationFix(
      {required this.latitude,
      required this.longitude,
      required this.accuracy,
      required this.timestamp});
  final double latitude, longitude, accuracy;
  final DateTime timestamp;
}

/// Non-final methods intentionally allow a fake bridge in widget tests.
class IndoorLocationBridge {
  const IndoorLocationBridge(
      {MethodChannel channel = const MethodChannel('apt_ev/indoor_location')})
      : _channel = channel;
  final MethodChannel _channel;
  Future<void> configure(HomeArea area) =>
      _channel.invokeMethod<void>('configure', area.toJson());
  Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disable');
    } on MissingPluginException {/* Unsupported host. */}
  }

  /// Settings operations may finish after an account switch. Native code checks the owner.
  Future<void> disableForAccount(String accountScope) async {
    try {
      await _channel
          .invokeMethod<void>('disable', {'accountScope': accountScope});
    } on MissingPluginException {/* Unsupported host. */}
  }

  Future<IndoorLocationStatus> status() async {
    try {
      final data = await _channel.invokeMapMethod<dynamic, dynamic>('status');
      return IndoorLocationStatus.fromMap(data ?? {});
    } on MissingPluginException {
      return const IndoorLocationStatus();
    }
  }

  Future<void> requestPermissions() =>
      _channel.invokeMethod<void>('requestPermissions');
  Future<void> requestBackgroundPermission() =>
      _channel.invokeMethod<void>('requestBackgroundPermission');
  Future<bool> openSettings(String target) async {
    if (!const {'locationServices', 'location', 'background', 'notifications'}
        .contains(target)) {
      throw ArgumentError.value(target, 'target');
    }
    try {
      return await _channel
              .invokeMethod<bool>('openSettings', {'target': target}) ??
          false;
    } on MissingPluginException {
      return openAppSettings();
    }
  }

  Future<Map<String, dynamic>?> consumeEntry() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>('consumeEntry');
    } on MissingPluginException {
      return null;
    }
  }

  Future<OutdoorLocationFix?> currentLocation() async {
    final map =
        await _channel.invokeMapMethod<dynamic, dynamic>('currentLocation');
    if (map == null) return null;
    if (map['latitude'] is! num ||
        map['longitude'] is! num ||
        map['accuracy'] is! num ||
        map['timestamp'] is! num ||
        !(map['timestamp'] as num).isFinite ||
        (map['timestamp'] as num).abs() > 8640000000000000) {
      return null;
    }
    final lat = (map['latitude'] as num).toDouble();
    final lon = (map['longitude'] as num).toDouble();
    final accuracy = (map['accuracy'] as num).toDouble();
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as num).toInt());
    if (!lat.isFinite ||
        lat.abs() > 90 ||
        !lon.isFinite ||
        lon.abs() > 180 ||
        !accuracy.isFinite ||
        accuracy < 0) {
      return null;
    }
    return OutdoorLocationFix(
        latitude: lat,
        longitude: lon,
        accuracy: accuracy,
        timestamp: timestamp);
  }
}
