/// Account-private outdoor home region. Coordinates never leave local storage.
class HomeArea {
  HomeArea(
      {required this.accountScope,
      required this.latitude,
      required this.longitude,
      this.radiusMeters = 200,
      this.revision = 1,
      this.enabled = false}) {
    if (accountScope.trim().isEmpty ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !radiusMeters.isFinite ||
        radiusMeters < 100 ||
        radiusMeters > 1000 ||
        revision < 1) {
      throw ArgumentError('Invalid home area');
    }
  }
  final String accountScope;
  final double latitude, longitude, radiusMeters;
  final int revision;
  final bool enabled;
  HomeArea copyWith(
          {double? latitude,
          double? longitude,
          double? radiusMeters,
          int? revision,
          bool? enabled}) =>
      HomeArea(
          accountScope: accountScope,
          latitude: latitude ?? this.latitude,
          longitude: longitude ?? this.longitude,
          radiusMeters: radiusMeters ?? this.radiusMeters,
          revision: revision ?? this.revision,
          enabled: enabled ?? this.enabled);
  Map<String, dynamic> toJson() => {
        'accountScope': accountScope,
        'siteId': 'home',
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'revision': revision,
        'enabled': enabled
      };
  factory HomeArea.fromJson(Map<String, dynamic> json) => HomeArea(
      accountScope: json['accountScope'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radiusMeters'] as num).toDouble(),
      revision: json['revision'] as int,
      enabled: json['enabled'] as bool);
}
