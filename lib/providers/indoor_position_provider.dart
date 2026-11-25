import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/indoor_positioning.dart';
import '../services/beacon_observer.dart';
import '../services/fingerprint_positioner.dart';
import '../services/indoor_survey_store.dart';

/// One foreground screen owns this controller and its BLE scan.
class IndoorPositionProvider extends ChangeNotifier {
  IndoorPositionProvider(
      {required this.accountScope,
      IndoorSurveyStore? store,
      BeaconObserver? observer})
      : store = store ?? IndoorSurveyStore(),
        _ownsStore = store == null,
        observer = observer ?? BeaconObserver() {
    this.observer.addListener(refresh);
  }
  final String accountScope;
  final IndoorSurveyStore store;
  final bool _ownsStore;
  final BeaconObserver observer;
  List<SurveySession> _sessions = [];
  List<SurveySession> get sessions => List.unmodifiable(_sessions);
  PositionEstimate? estimate;
  bool loading = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  String? error;
  bool get isScanning => observer.isScanning;

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    loading = true;
    _notify();
    try {
      final loaded = await store.load(accountScope);
      if (_disposed || generation != _loadGeneration) return;
      _sessions = loaded;
      error = null;
    } catch (_) {
      if (_disposed || generation != _loadGeneration) return;
      error = '저장된 측정 기록을 읽지 못했습니다. 다시 시도해 주세요.';
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        loading = false;
        refresh();
      }
    }
  }

  void usePublishedSurveys(List<SurveySession> sessions) {
    if (sessions.any((s) => s.accountScope != 'published')) {
      throw ArgumentError('Only published surveys may be shared');
    }
    _sessions = List.of(sessions);
    refresh();
  }

  Future<void> saveSurvey(SurveySession session) async {
    if (_disposed) return;
    if (session.accountScope != accountScope) {
      throw ArgumentError('Account mismatch');
    }
    if (!session.usable) throw ArgumentError('Complete measurements required');
    await store.save(session);
    if (!_disposed) await load();
  }

  Future<void> deleteSurvey(String id) async {
    if (_disposed) return;
    await store.delete(accountScope, id);
    if (!_disposed) await load();
  }

  Future<void> excludeSurvey(String id, bool excluded) async {
    if (_disposed) return;
    await store.setExcluded(accountScope, id, excluded);
    if (!_disposed) await load();
  }

  Future<void> start() async {
    if (!_disposed) await observer.start();
  }

  Future<void> stop() async {
    await observer.stop();
    if (_disposed) return;
    estimate = null;
    _notify();
  }

  void refresh([DateTime? now]) {
    if (_disposed) return;
    final time = now ?? observer.clock();
    estimate = observer.isScanning
        ? const FingerprintPositioner()
            .estimate(_sessions, observer.recent(time), now: time)
        : null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_loadGeneration;
    observer.removeListener(refresh);
    observer.dispose();
    if (_ownsStore) unawaited(store.close());
    super.dispose();
  }
}
