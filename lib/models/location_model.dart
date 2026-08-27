class LocationModel {
  static const String modeWalking = 'walking';
  static const String modeBiking = 'biking';
  static const String modeCar = 'car';
  static const String modeBus = 'bus';

  static const List<String> supportedTravelModes = [
    modeWalking,
    modeBiking,
    modeCar,
    modeBus,
  ];

  static const String sharingTypeLive = 'live';
  static const String sharingTypeStatic = 'static';
  static const String sharingTypeRoute = 'route';

  static const List<String> supportedSharingTypes = [
    sharingTypeLive,
    sharingTypeStatic,
    sharingTypeRoute,
  ];

  final String userId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final int timestamp; // epoch milliseconds
  final String travelMode;
  final int? expiresAt; // epoch milliseconds; null represents indefinite sharing
  final String sharingType;

  const LocationModel({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    required this.timestamp,
    this.travelMode = modeWalking,
    this.expiresAt,
    this.sharingType = sharingTypeLive,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().millisecondsSinceEpoch >= expiresAt!;

  bool get isIndefinite => expiresAt == null;

  Duration? get remainingDuration {
    if (expiresAt == null) return null;
    if (isExpired) return Duration.zero;
    return Duration(milliseconds: expiresAt! - DateTime.now().millisecondsSinceEpoch);
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': timestamp,
      'travelMode': travelMode,
      'expiresAt': expiresAt,
      'sharingType': sharingType,
    };
  }

  factory LocationModel.fromMap(Map<dynamic, dynamic> map, String userId) {
    int parsedTimestamp;
    final rawTimestamp = map['timestamp'] ?? map['updatedAt'];
    if (rawTimestamp is num) {
      parsedTimestamp = rawTimestamp.toInt();
    } else if (rawTimestamp is String) {
      parsedTimestamp = DateTime.tryParse(rawTimestamp)?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;
    } else {
      parsedTimestamp = DateTime.now().millisecondsSinceEpoch;
    }

    final rawMode = map['travelMode'] as String?;
    final mode = (rawMode != null && supportedTravelModes.contains(rawMode))
        ? rawMode
        : modeWalking;

    final rawExpiresAt = map['expiresAt'];
    int? parsedExpiresAt;
    if (rawExpiresAt is num) {
      parsedExpiresAt = rawExpiresAt.toInt();
    } else if (rawExpiresAt is String) {
      parsedExpiresAt = int.tryParse(rawExpiresAt) ??
          DateTime.tryParse(rawExpiresAt)?.millisecondsSinceEpoch;
    }

    final rawSharingType = map['sharingType'] as String?;
    final sharingType = (rawSharingType != null &&
            supportedSharingTypes.contains(rawSharingType))
        ? rawSharingType
        : sharingTypeLive;

    return LocationModel(
      userId: userId,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      timestamp: parsedTimestamp,
      travelMode: mode,
      expiresAt: parsedExpiresAt,
      sharingType: sharingType,
    );
  }

  LocationModel copyWith({
    String? userId,
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    double? accuracy,
    int? timestamp,
    String? travelMode,
    int? expiresAt,
    bool clearExpiresAt = false,
    String? sharingType,
  }) {
    return LocationModel(
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      travelMode: travelMode ?? this.travelMode,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      sharingType: sharingType ?? this.sharingType,
    );
  }
}
