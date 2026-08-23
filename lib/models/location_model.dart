class LocationModel {
  final String userId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  const LocationModel({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map, String userId) {
    return LocationModel(
      userId: userId,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
