import '../models/home_area.dart';

/// Native notification delivery is independent of Firebase initialization.
class IndoorEntryNotification {
  const IndoorEntryNotification(
      {required this.accountScope,
      required this.visitId,
      required this.areaRevision});
  final String accountScope, visitId;
  final int areaRevision;
  static IndoorEntryNotification? parse(Map<String, dynamic>? payload) {
    if (payload == null ||
        payload['type'] != 'indoorEntry' ||
        payload['siteId'] != 'home' ||
        payload['accountScope'] is! String ||
        (payload['accountScope'] as String).isEmpty ||
        payload['visitId'] is! String ||
        (payload['visitId'] as String).isEmpty ||
        payload['areaRevision'] is! int ||
        (payload['areaRevision'] as int) < 1) {
      return null;
    }
    return IndoorEntryNotification(
        accountScope: payload['accountScope'] as String,
        visitId: payload['visitId'] as String,
        areaRevision: payload['areaRevision'] as int);
  }

  bool matches(HomeArea area) =>
      area.enabled &&
      area.accountScope == accountScope &&
      area.revision == areaRevision;
}
