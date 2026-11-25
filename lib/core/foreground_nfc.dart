import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android owns RF lifecycle and tag-removal debounce; Dart owns URL trust.
class ForegroundNfc {
  ForegroundNfc(this.onUri);

  final bool Function(String uri) onUri;
  static const _channel = MethodChannel('apt_ev/foreground_nfc');
  bool _started = false;
  int _lastScanId = 0;

  Future<void> start() async {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _started = true;
    _lastScanId = 0;
    _channel.setMethodCallHandler((call) async {
      if (!_started || call.method != 'tag' || call.arguments is! Map) return;
      final arguments = call.arguments as Map;
      final scanId = arguments['scanId'];
      final raw = arguments['uri'];
      if (scanId is! int || scanId <= _lastScanId || raw is! String) return;
      _lastScanId = scanId;
      if (raw.length > 4096) return;
      final uri = Uri.tryParse(raw);
      if (uri == null || !uri.hasAuthority) return;
      onUri(raw);
    });
    try {
      await _channel.invokeMethod<bool>('start');
    } on MissingPluginException {
      // NFC is optional, including on local test and unsupported platforms.
    } on PlatformException {
      // A disabled/unavailable NFC service must not prevent app startup.
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Optional platform capability.
    } on PlatformException {
      // Native activity lifecycle also disables reader mode.
    }
  }
}
