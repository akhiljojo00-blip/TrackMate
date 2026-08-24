class SosAlertModel {
  final String id;
  final String senderUid;
  final String senderName;
  final double latitude;
  final double longitude;
  final int? batteryLevel;
  final int timestamp;
  final bool isActive;

  const SosAlertModel({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.latitude,
    required this.longitude,
    this.batteryLevel,
    required this.timestamp,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'latitude': latitude,
      'longitude': longitude,
      'batteryLevel': batteryLevel,
      'timestamp': timestamp,
      'isActive': isActive,
    };
  }

  factory SosAlertModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return SosAlertModel(
      id: id,
      senderUid: map['senderUid']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      batteryLevel: (map['batteryLevel'] as num?)?.toInt(),
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  SosAlertModel copyWith({
    String? id,
    String? senderUid,
    String? senderName,
    double? latitude,
    double? longitude,
    int? batteryLevel,
    int? timestamp,
    bool? isActive,
  }) {
    return SosAlertModel(
      id: id ?? this.id,
      senderUid: senderUid ?? this.senderUid,
      senderName: senderName ?? this.senderName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      timestamp: timestamp ?? this.timestamp,
      isActive: isActive ?? this.isActive,
    );
  }
}
