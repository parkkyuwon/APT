import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/services/indoor_entry_policy.dart';

void main() {
  final start = DateTime.utc(2026, 11, 23);
  test('permission or service loss reports unavailable and resets timer', () {
    final p = IndoorEntryPolicy()..recordInside(start);
    p.evaluate(now: start, observing: true);
    p.evaluate(now: start.add(const Duration(seconds: 31)), observing: false);
    expect(p.state, IndoorEntryState.unavailable);
    expect(
        p.evaluate(
            now: start.add(const Duration(seconds: 32)), observing: true),
        isFalse);
    expect(p.state, IndoorEntryState.armed);
  });
  test('stale and boundary fixes do not establish home evidence', () {
    final p = IndoorEntryPolicy();
    p.recordFix(
        now: start,
        timestamp: start.subtract(const Duration(seconds: 16)),
        distanceMeters: 0,
        accuracyMeters: 5,
        radiusMeters: 200);
    expect(p.hasInsideEvidence, isFalse);
    p.recordFix(
        now: start,
        timestamp: start,
        distanceMeters: 190,
        accuracyMeters: 20,
        radiusMeters: 200);
    expect(p.hasInsideEvidence, isFalse);
    p.recordFix(
        now: start,
        timestamp: start,
        distanceMeters: 100,
        accuracyMeters: 20,
        radiusMeters: 200);
    expect(p.hasInsideEvidence, isTrue);
  });
  test('requires recent inside evidence and continuous observable degradation',
      () {
    final p = IndoorEntryPolicy();
    expect(p.evaluate(now: start, observing: true), isFalse);
    p.recordInside(start);
    expect(p.evaluate(now: start, observing: true), isFalse);
    expect(
        p.evaluate(
            now: start.add(const Duration(seconds: 30)), observing: true),
        isTrue);
    expect(
        p.evaluate(
            now: start.add(const Duration(seconds: 60)), observing: true),
        isFalse);
  });
  test('unavailable observation and expired evidence never notify', () {
    final p = IndoorEntryPolicy()..recordInside(start);
    p.evaluate(now: start, observing: true);
    expect(
        p.evaluate(
            now: start.add(const Duration(seconds: 40)), observing: false),
        isFalse);
    expect(
        p.evaluate(
            now: start.add(const Duration(seconds: 41)), observing: true),
        isFalse);
    expect(
        p.evaluate(
            now: start.add(const Duration(minutes: 21)), observing: true),
        isFalse);
  });
  test('two trusted outside samples ten seconds apart allow a new visit', () {
    final p = IndoorEntryPolicy()..recordInside(start);
    p.evaluate(now: start, observing: true);
    expect(
        p.evaluate(
            now: start.add(const Duration(seconds: 30)), observing: true),
        isTrue);
    p.recordOutside(start.add(const Duration(seconds: 31)), trusted: false);
    expect(p.hasInsideEvidence, isTrue);
    p.recordOutside(start.add(const Duration(seconds: 32)), trusted: true);
    p.recordOutside(start.add(const Duration(seconds: 42)), trusted: true);
    expect(p.hasInsideEvidence, isFalse);
    p.recordInside(start.add(const Duration(seconds: 43)));
    p.evaluate(now: start.add(const Duration(seconds: 43)), observing: true);
    expect(
        p.evaluate(
            now: start.add(const Duration(seconds: 73)), observing: true),
        isTrue);
  });
  test('clock reversal resets evidence and healthy samples reset degradation',
      () {
    final p = IndoorEntryPolicy()..recordInside(start);
    p.evaluate(now: start, observing: true);
    p.evaluate(
        now: start.add(const Duration(seconds: 20)),
        observing: true,
        healthyLocation: true);
    expect(
        p.evaluate(
            now: start.add(const Duration(seconds: 30)), observing: true),
        isFalse);
    expect(
        p.evaluate(
            now: start.subtract(const Duration(seconds: 1)), observing: true),
        isFalse);
    expect(p.hasInsideEvidence, isFalse);
  });
}
