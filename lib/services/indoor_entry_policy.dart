enum IndoorEntryState {
  disabled,
  outside,
  armed,
  locationDegraded,
  notified,
  unavailable
}

/// Deterministic policy. A caller must pass original measurement times and only
/// mark observation true while the OS is actually observing location.
class IndoorEntryPolicy {
  DateTime? _inside, _outside, _degraded, _lastNow;
  bool _notified = false;
  int visitId = 0;
  IndoorEntryState state = IndoorEntryState.outside;
  bool get hasInsideEvidence => _inside != null;
  void reset() {
    _inside = _outside = _degraded = _lastNow = null;
    _notified = false;
    state = IndoorEntryState.outside;
  }

  void recordInside(DateTime timestamp) {
    if (_inside == null) {
      visitId++;
      _notified = false;
    }
    _inside = timestamp;
    _outside = null;
    state = _notified ? IndoorEntryState.notified : IndoorEntryState.armed;
  }

  void recordOutside(DateTime timestamp, {required bool trusted}) {
    if (!trusted) {
      _outside = null;
      return;
    }
    if (_outside != null &&
        timestamp.difference(_outside!) >= const Duration(seconds: 10)) {
      reset();
    } else {
      _outside ??= timestamp;
    }
  }

  /// Returns true once per visit, only when a notification should be emitted.
  bool evaluate(
      {required DateTime now,
      required bool observing,
      bool enabled = true,
      bool healthyLocation = false,
      bool notificationAllowed = true}) {
    if (!enabled ||
        (_lastNow != null && now.isBefore(_lastNow!)) ||
        (_inside != null &&
            (now.isBefore(_inside!) ||
                now.difference(_inside!) > const Duration(minutes: 20)))) {
      reset();
      if (!enabled) state = IndoorEntryState.disabled;
      return false;
    }
    _lastNow = now;
    if (!observing || healthyLocation) {
      _degraded = null;
      state = !observing
          ? IndoorEntryState.unavailable
          : (_inside == null
              ? IndoorEntryState.outside
              : (_notified
                  ? IndoorEntryState.notified
                  : IndoorEntryState.armed));
      return false;
    }
    if (_inside == null) return false;
    _degraded ??= now;
    state = _notified ? IndoorEntryState.notified : IndoorEntryState.armed;
    if (_notified || now.difference(_degraded!) < const Duration(seconds: 30)) {
      return false;
    }
    state = IndoorEntryState.locationDegraded;
    if (!notificationAllowed) return false;
    _notified = true;
    state = IndoorEntryState.notified;
    return true;
  }

  /// Classify a fresh fix using its uncertainty circle, never callback time.
  void recordFix(
      {required DateTime now,
      required DateTime timestamp,
      required double distanceMeters,
      required double accuracyMeters,
      required double radiusMeters}) {
    if (timestamp.isAfter(now) ||
        now.difference(timestamp) > const Duration(seconds: 15) ||
        !accuracyMeters.isFinite ||
        accuracyMeters < 0 ||
        accuracyMeters > 30 ||
        !distanceMeters.isFinite ||
        distanceMeters < 0) {
      _outside = null;
      return;
    }
    _degraded = null;
    if (distanceMeters + accuracyMeters <= radiusMeters) {
      recordInside(timestamp);
    } else if (distanceMeters - accuracyMeters > radiusMeters + 50) {
      recordOutside(timestamp, trusted: true);
    } else {
      _outside = null;
    }
  }
}
