import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../config/app_config.dart';
import '../core/indoor_location_bridge.dart';
import '../providers/auth_provider.dart';
import '../providers/indoor_dataset_provider.dart';
import 'home_area_store.dart';
import 'indoor_entry_notifications.dart';
import 'indoor_positioning_api.dart';

/// Binds shared downloads and native monitoring to the authenticated app session.
class IndoorAccessController extends ChangeNotifier
    with WidgetsBindingObserver {
  IndoorAccessController(this._api, this._auth,
      {IndoorLocationBridge? bridge,
      HomeAreaStore? areaStore,
      bool? supported,
      IndoorDatasetProvider Function(String)? datasetFactory})
      : _bridge = bridge ?? const IndoorLocationBridge(),
        _datasetFactory = datasetFactory,
        _areaStore = areaStore ?? HomeAreaStore(),
        _supported = supported ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS)) {
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_bind);
    _bind();
  }
  final IndoorPositioningApi _api;
  final AuthProvider _auth;
  final IndoorLocationBridge _bridge;
  final HomeAreaStore _areaStore;
  final bool _supported;
  final IndoorDatasetProvider Function(String)? _datasetFactory;
  IndoorDatasetProvider? publication;
  String? _scope;
  bool _disposed = false,
      _restoring = false,
      _consuming = false,
      _bound = false;
  bool _foreground = WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  int _generation = 0;
  Timer? _poll;
  IndoorEntryNotification? _pending;
  String? _lastVisit;
  String? get pendingVisit => _pending?.visitId;
  String? get accountScope => _scope;
  bool get enabled => publication?.dataset?.enabled == true;
  Future<void> _nativeChain = Future.value();

  void _bind() {
    if (_disposed || _auth.stage == AuthStage.initializing) return;
    final approved =
        _auth.stage == AuthStage.approved || _auth.stage == AuthStage.admin;
    final scope = approved ? _auth.session?.email : null;
    final cacheScope = scope == null
        ? null
        : '${AppConfig.apiBaseUrl}|$scope|${_auth.isAdmin}';
    if (_bound && _scope == scope && publication?.cacheScope == cacheScope) {
      return;
    }
    _bound = true;
    final previous = _scope;
    _scope = scope;
    _generation++;
    _pending = null;
    _lastVisit = null;
    publication?.removeListener(_changed);
    publication?.dispose();
    publication = null;
    _poll?.cancel();
    // Do not discard a cold notification during initial authentication.
    if (_supported && (previous != null || scope == null)) {
      _queueNative(_bridge.disable);
    }
    if (_supported && scope != null) {
      publication = _datasetFactory?.call(cacheScope!) ??
          IndoorDatasetProvider(_api, cacheScope: cacheScope!);
      publication!.addListener(_changed);
      unawaited(publication!.refresh());
      if (_foreground) {
        _poll = Timer.periodic(
            const Duration(seconds: 3), (_) => unawaited(_consume()));
      }
    }
    _notify();
  }

  void _queueNative(Future<void> Function() action) {
    _nativeChain = _nativeChain.then((_) async {
      if (!_disposed) await action();
    }).catchError((Object _) {/* UI reads native status in settings. */});
  }

  void _changed() {
    if (!enabled) _pending = null;
    _notify();
    if (!_supported) return;
    if (publication?.dataset != null || publication?.revoked == true) {
      _queueNative(_restore);
    }
  }

  Future<void> _restore() async {
    if (_restoring || _scope == null) return;
    _restoring = true;
    final generation = _generation;
    try {
      if (!enabled) {
        await _bridge.disable();
        return;
      }
      final area = await _areaStore.load(_scope!);
      if (_disposed || generation != _generation) return;
      if (!enabled) {
        await _bridge.disable();
        return;
      }
      if (area?.enabled == true) {
        await _bridge.configure(area!);
      } else {
        await _bridge.disable();
      }
      await _consume();
    } finally {
      _restoring = false;
    }
  }

  Future<void> _consume() async {
    if (!_supported ||
        _scope == null ||
        !enabled ||
        _disposed ||
        !_foreground ||
        _consuming) {
      return;
    }
    _consuming = true;
    final generation = _generation;
    try {
      final entry = IndoorEntryNotification.parse(await _bridge.consumeEntry());
      if (entry == null ||
          _disposed ||
          generation != _generation ||
          entry.accountScope != _scope ||
          entry.visitId == _lastVisit) {
        return;
      }
      final area = await _areaStore.load(_scope!);
      if (area == null ||
          !entry.matches(area) ||
          _disposed ||
          generation != _generation ||
          !enabled ||
          entry.visitId == _lastVisit ||
          !_foreground) {
        return;
      }
      _lastVisit = entry.visitId;
      _pending = entry;
      _notify();
    } catch (_) {
      /* Unsupported or suspended platforms do not imply GPS loss. */
    } finally {
      _consuming = false;
    }
  }

  Future<bool> takeEntry() async {
    final entry = _pending;
    _pending = null;
    if (entry == null || !enabled || _scope == null) return false;
    final generation = _generation;
    final area = await _areaStore.load(_scope!);
    return !_disposed &&
        generation == _generation &&
        _foreground &&
        enabled &&
        area != null &&
        entry.matches(area);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _poll?.cancel();
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed && _scope != null && _supported) {
      unawaited(publication?.refresh());
      _queueNative(_restore);
      _poll = Timer.periodic(
          const Duration(seconds: 3), (_) => unawaited(_consume()));
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _auth.removeListener(_bind);
    WidgetsBinding.instance.removeObserver(this);
    publication?.removeListener(_changed);
    publication?.dispose();
    _poll?.cancel();
    super.dispose();
  }
}
