class LocationModel {
  final String userId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final int timestamp; // epoch milliseconds

  const LocationModel({
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    required this.timestamp,
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

    return LocationModel(
      userId: userId,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      timestamp: parsedTimestamp,
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
  }) {
    return LocationModel(
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
