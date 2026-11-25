import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apt_ev_charging/screens/admin/console_beacon_scan.dart';

void main() {
  group('scanModeLabel', () {
    test('opportunistic → "Passive"', () {
      expect(scanModeLabel(AndroidScanMode.opportunistic), 'Passive');
    });
    test('lowPower → "LowPower"', () {
      expect(scanModeLabel(AndroidScanMode.lowPower), 'LowPower');
    });
    test('balanced → "Balanced"', () {
      expect(scanModeLabel(AndroidScanMode.balanced), 'Balanced');
    });
    test('lowLatency → "Active"', () {
      expect(scanModeLabel(AndroidScanMode.lowLatency), 'Active');
    });
  });

  group('scanModeDescription', () {
    test('opportunistic 설명에 "다른 앱" 포함', () {
      expect(
        scanModeDescription(AndroidScanMode.opportunistic),
        contains('다른 앱'),
      );
    });
    test('lowPower 설명에 "배터리 절약" 포함', () {
      expect(
        scanModeDescription(AndroidScanMode.lowPower),
        contains('배터리 절약'),
      );
    });
    test('balanced 설명에 "균형" 포함', () {
      expect(
        scanModeDescription(AndroidScanMode.balanced),
        contains('균형'),
      );
    });
    test('lowLatency 설명에 "가장 빠른" 포함', () {
      expect(
        scanModeDescription(AndroidScanMode.lowLatency),
        contains('가장 빠른'),
      );
    });
  });
}
