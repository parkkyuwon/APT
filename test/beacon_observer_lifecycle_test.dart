import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/models/indoor_positioning.dart';
import 'package:apt_ev_charging/services/beacon_observer.dart';

class DelayedScanSource implements BeaconScanSource {
  final began = Completer<void>();
  final release = Completer<void>();
  bool active = false;
  int stops = 0;
  @override
  Stream<List<BeaconObservation>> get packets => const Stream.empty();
  @override
  Stream<bool> get available => const Stream.empty();
  @override
  Future<void> prepare() async {}
  @override
  Future<void> start() async {
    began.complete();
    await release.future;
    active = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    active = false;
  }
}

void main() {
  test(
      'cancel during native start retains ownership then stops late completion',
      () async {
    final source = DelayedScanSource();
    final observer = BeaconObserver(source: source);
    final starting = observer.start();
    await source.began.future;
    await observer.stop();
    final otherSource = DelayedScanSource();
    final other = BeaconObserver(source: otherSource);
    await other.start();
    expect(other.error, isNotNull);
    expect(otherSource.began.isCompleted, isFalse);
    source.release.complete();
    await starting;
    expect(source.active, isFalse);
    expect(observer.isScanning, isFalse);
    observer.dispose();
    other.dispose();
  });
  test('dispose while native scan starts never publishes active state',
      () async {
    final source = DelayedScanSource();
    final observer = BeaconObserver(source: source);
    final starting = observer.start();
    await source.began.future;
    observer.dispose();
    source.release.complete();
    await starting;
    expect(source.active, isFalse);
    expect(observer.isScanning, isFalse);
  });
}
