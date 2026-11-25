import Flutter
import CoreLocation
import CryptoKit
import UserNotifications
import UIKit

final class IndoorEntryPolicy {
  private var evidence: TimeInterval?
  private var degraded: TimeInterval?
  private var notified = false
  func arm(now: TimeInterval) { evidence = now; degraded = nil; notified = false }
  func refresh(now: TimeInterval) { evidence = now }
  func evaluate(now: TimeInterval, observing: Bool, poor: Bool) -> Bool {
    guard observing, let evidence = evidence, now >= evidence, now - evidence <= 1200 else { degraded = nil; return false }
    guard poor else { degraded = nil; return false }
    if degraded == nil { degraded = now }
    guard let degraded = degraded, now >= degraded else { self.degraded = nil; return false }
    if !notified && now - degraded >= 30 { notified = true; return true }
    return false
  }
}

/// A native observer can be relaunched by region monitoring; it never restores a loss timer.
final class IndoorLocationMonitor: NSObject, CLLocationManagerDelegate {
  static let shared = IndoorLocationMonitor()
  private let manager = CLLocationManager()
  private let currentManager = CLLocationManager()
  private var config: [String: Any]?
  private var visit: String?
  private var notified = false
  private var pendingEntry: [String: Any]?
  private var reason = "disabled"
  private var observing = false
  private var started: TimeInterval = 0
  private var lastGood: TimeInterval = 0
  private var lastObservation: TimeInterval?
  private var outsideSince: TimeInterval?
  private var outsideCount = 0
  private var policy = IndoorEntryPolicy()
  private var timer: Timer?
  private var locationResult: FlutterResult?
  private var locationTimeout: DispatchWorkItem?
  private var notificationAllowed = false
  private var channel: FlutterMethodChannel?
  private let regionId = "apt_ev.home"
  private var regionIdentifier: String {
    guard let config = config, let data = try? JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]) else { return regionId }
    return regionId + "." + SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
  }
  private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
  private var file: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("indoor_location.json") }

  private override init() {
    super.init()
    manager.delegate = self; currentManager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    currentManager.desiredAccuracy = kCLLocationAccuracyBest
    manager.pausesLocationUpdatesAutomatically = true
    manager.allowsBackgroundLocationUpdates = true
    if let data = try? Data(contentsOf: file), let state = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
      config = state["config"] as? [String: Any]; visit = state["visit"] as? String
      notified = state["notified"] as? Bool ?? false; pendingEntry = state["entry"] as? [String: Any]
    }
    refreshNotificationPermission()
    register()
  }
  func attach(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "apt_ev/indoor_location", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
  }
  private func persist() {
    var state: [String: Any] = ["notified": notified]
    state["config"] = config; state["visit"] = visit; state["entry"] = pendingEntry
    do {
      try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      let data = try JSONSerialization.data(withJSONObject: state)
      try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
      var url = file; var values = URLResourceValues(); values.isExcludedFromBackup = true; try url.setResourceValues(values)
    } catch { reason = "storageUnavailable" }
  }
  private var locationAllowed: Bool { manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse }
  private var backgroundAllowed: Bool { manager.authorizationStatus == .authorizedAlways && UIApplication.shared.backgroundRefreshStatus == .available }
  private func refreshNotificationPermission() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async { self.notificationAllowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional }
    }
  }
  private func status() -> [String: Any] {
    let supported = CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
    var value = reason
    if config == nil { value = "disabled" }
    else if !supported { value = "regionMonitoringUnavailable" }
    else if !CLLocationManager.locationServicesEnabled() || !locationAllowed { value = "locationUnavailable" }
    else if manager.accuracyAuthorization != .fullAccuracy { value = "preciseLocationRequired" }
    else if !backgroundAllowed { value = "backgroundPermissionRequired" }
    else if !notificationAllowed { value = "notificationPermissionRequired" }
    return ["supported": supported, "monitoring": value == "monitoring", "reason": value,
      "locationAllowed": locationAllowed && CLLocationManager.locationServicesEnabled(), "backgroundAllowed": backgroundAllowed,
      "notificationAllowed": notificationAllowed]
  }
  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      guard let args = call.arguments as? [String: Any], let lat = args["latitude"] as? Double, let lon = args["longitude"] as? Double,
        let radius = args["radiusMeters"] as? Double, let scope = args["accountScope"] as? String,
        let revision = args["revision"] as? Int, args["siteId"] as? String == "home", !scope.isEmpty,
        lat.isFinite, lon.isFinite, radius.isFinite, (-90...90).contains(lat), (-180...180).contains(lon), (100...1000).contains(radius) else {
          result(FlutterError(code: "invalid", message: "Invalid home area", details: nil)); return
      }
      if args["enabled"] as? Bool != true { disable(); result(status()); return }
      let next: [String: Any] = ["latitude": lat, "longitude": lon, "radiusMeters": radius, "accountScope": scope, "revision": revision, "siteId": "home"]
      if let config = config, NSDictionary(dictionary: config).isEqual(to: next) { register(); result(status()); return }
      disable(); config = next; persist(); register(); result(status())
    case "disable":
      let requestedScope = (call.arguments as? [String: Any])?["accountScope"] as? String
      if requestedScope == nil || requestedScope == config?["accountScope"] as? String { disable() }
      result(status())
    case "status": refreshNotificationPermission(); result(status())
    case "consumeEntry":
      let entry = pendingEntry; pendingEntry = nil; persist()
      if let entry = entry, valid(entry) { result(entry) } else { result(nil) }
    case "requestPermissions":
      manager.requestWhenInUseAuthorization()
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          DispatchQueue.main.async {
            self.notificationAllowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            result(self.status())
          }
        }
      }
    case "requestBackgroundPermission": manager.requestAlwaysAuthorization(); result(status())
    case "currentLocation":
      guard locationAllowed else { result(FlutterError(code: "permission", message: "Location permission required", details: nil)); return }
      guard locationResult == nil else { result(FlutterError(code: "busy", message: "Location request in progress", details: nil)); return }
      locationResult = result
      let timeout = DispatchWorkItem { [weak self] in self?.finishCurrent(nil) }
      locationTimeout = timeout; DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
      currentManager.requestLocation()
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func register() {
    guard let config = config, locationAllowed, backgroundAllowed, manager.accuracyAuthorization == .fullAccuracy,
      CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
    let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: config["latitude"] as! Double, longitude: config["longitude"] as! Double),
      radius: min(config["radiusMeters"] as! Double, manager.maximumRegionMonitoringDistance), identifier: regionIdentifier)
    region.notifyOnEntry = true; region.notifyOnExit = true
    if !manager.monitoredRegions.contains(where: { $0.identifier == regionIdentifier }) {
      reason = "registering"; manager.startMonitoring(for: region)
    } else { reason = "monitoring" }
  }
  private func disable() {
    stopObservation()
    for region in manager.monitoredRegions where region.identifier.hasPrefix(regionId) { manager.stopMonitoring(for: region) }
    config = nil; visit = nil; pendingEntry = nil; notified = false; reason = "disabled"
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [regionId])
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [regionId]); persist()
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if !locationAllowed || !backgroundAllowed { stopObservation() }
    register()
  }
  func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
    if region.identifier == regionIdentifier { reason = "monitoring"; manager.requestState(for: region) }
  }
  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) { reason = "regionMonitoringUnavailable"; stopObservation() }
  func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
    if region.identifier == regionIdentifier && state == .inside { enter() }
  }
  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) { if region.identifier == regionIdentifier { enter() } }
  // A geographic EXIT alone is uncertain and does not create a new visit.
  private func enter() {
    guard config != nil, locationAllowed, backgroundAllowed else { return }
    if visit == nil { visit = UUID().uuidString; notified = false; persist() }
    if observing { policy.refresh(now: now); return }
    lastObservation = nil
    policy = IndoorEntryPolicy(); policy.arm(now: now)
    started = now; lastGood = now; outsideSince = nil; outsideCount = 0
    observing = true; manager.startUpdatingLocation()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
  }
  private func stopObservation() {
    observing = false; timer?.invalidate(); timer = nil; manager.stopUpdatingLocation()
    policy = IndoorEntryPolicy()
  }
  func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) { reason = "observationPaused"; stopObservation() }
  private func tick() {
    guard observing, locationAllowed, backgroundAllowed, CLLocationManager.locationServicesEnabled(), config != nil, now >= started, now - started <= 1200 else { stopObservation(); return }
    // Fresh delegate callbacks are required; iOS may suspend delivery without an observable GPS failure.
    // A timer alone is never used as evidence that GPS disappeared on iOS.
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if manager === currentManager { finishCurrent(locations.last); return }
    tick()
    guard observing, let config = config else { return }
    for location in locations {
      guard location.timestamp.timeIntervalSinceNow <= 0, location.timestamp.timeIntervalSinceNow >= -15, location.horizontalAccuracy >= 0 else { continue }
      if let previous = lastObservation, now < previous || now - previous > 15 {
        _ = policy.evaluate(now: now, observing: false, poor: false)
      }
      lastObservation = now
      let center = CLLocation(latitude: config["latitude"] as! Double, longitude: config["longitude"] as! Double)
      let distance = location.distance(from: center)
      let accurate = location.horizontalAccuracy <= 30
      if accurate {
        lastGood = now; _ = policy.evaluate(now: now, observing: observing, poor: false)
        if distance + location.horizontalAccuracy <= config["radiusMeters"] as! Double { policy.refresh(now: now) }
        if distance - location.horizontalAccuracy > (config["radiusMeters"] as! Double) + 50 {
          if outsideSince == nil { outsideSince = now }; outsideCount += 1
          if outsideCount >= 2 && now - outsideSince! >= 10 {
            visit = nil; notified = false; pendingEntry = nil; persist(); stopObservation(); return
          }
        } else { outsideSince = nil; outsideCount = 0 }
      }
      if policy.evaluate(now: now, observing: observing, poor: location.horizontalAccuracy > 50), !notified, notificationAllowed { notifyEntry() }
    }
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if manager === currentManager { finishCurrent(nil); return }
    // locationUnknown is transient, but does not prove observation continuity across suspension.
    reason = "observationUnavailable"; stopObservation()
  }
  private func finishCurrent(_ location: CLLocation?) {
    locationTimeout?.cancel(); locationTimeout = nil
    guard let result = locationResult else { return }; locationResult = nil
    if let location = location, location.horizontalAccuracy >= 0, location.timestamp.timeIntervalSinceNow <= 0, location.timestamp.timeIntervalSinceNow >= -15 {
      result(["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude,
        "accuracy": location.horizontalAccuracy, "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000)])
    } else { result(FlutterError(code: "unavailable", message: "Fresh location unavailable", details: nil)) }
  }
  private func notifyEntry() {
    guard let config = config, let visit = visit else { return }
    let content = UNMutableNotificationContent()
    content.title = "\u{C2E4}\u{B0B4} \u{C704}\u{CE58} \u{C548}\u{B0B4}"
    content.body = "\u{C2E4}\u{B0B4} \u{C9C0}\u{B3C4}\u{B97C} \u{C5F4}\u{C5B4} \u{C704}\u{CE58}\u{B97C} \u{D655}\u{C778}\u{D558}\u{C138}\u{C694}."
    content.sound = .default
    content.userInfo = ["type": "indoorEntry", "version": 1, "siteId": "home", "visitId": visit,
      "areaRevision": config["revision"]!, "accountScope": config["accountScope"]!]
    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: regionId, content: content, trigger: nil)) { error in
      DispatchQueue.main.async {
        guard self.visit == visit, let current = self.config,
          NSDictionary(dictionary: current).isEqual(to: config) else {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [self.regionId]); return
        }
        if error == nil { self.notified = true; self.persist() }
      }
    }
  }
  private func valid(_ entry: [String: Any]) -> Bool {
    guard let config = config else { return false }
    return entry["type"] as? String == "indoorEntry" && entry["accountScope"] as? String == config["accountScope"] as? String &&
      entry["areaRevision"] as? Int == config["revision"] as? Int && entry["visitId"] as? String == visit
  }
  func consumeResponse(_ response: UNNotificationResponse) -> Bool {
    let entry = response.notification.request.content.userInfo
    guard entry["type"] as? String == "indoorEntry" else { return false }
    var payload: [String: Any] = [:]
    for (key, value) in entry { if let key = key as? String { payload[key] = value } }
    if valid(payload) { pendingEntry = payload; persist() }
    return true
  }
}
