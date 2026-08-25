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

  final String userId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final int timestamp; // epoch milliseconds
  final String travelMode;

  const LocationModel({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    required this.timestamp,
    this.travelMode = modeWalking,
  });

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

    return LocationModel(
      userId: userId,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      timestamp: parsedTimestamp,
      travelMode: mode,
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
    );
  }
}
