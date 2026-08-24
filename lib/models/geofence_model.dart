class GeofenceModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int iconPreset;
  final bool notifyOnEntry;
  final bool notifyOnExit;
  final List<String> targetRecipientUids;
  final List<String> targetGroupIds;
  final int createdAt;
  final bool isEnabled;

  const GeofenceModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150.0,
    this.iconPreset = 0,
    this.notifyOnEntry = true,
    this.notifyOnExit = true,
    this.targetRecipientUids = const [],
    this.targetGroupIds = const [],
    required this.createdAt,
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'iconPreset': iconPreset,
      'notifyOnEntry': notifyOnEntry,
      'notifyOnExit': notifyOnExit,
      'targetRecipientUids': targetRecipientUids,
      'targetGroupIds': targetGroupIds,
      'createdAt': createdAt,
      'isEnabled': isEnabled,
    };
  }

  factory GeofenceModel.fromMap(Map<dynamic, dynamic> map, String id) {
    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      } else if (raw is Map) {
        return raw.values.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return GeofenceModel(
      id: id,
      name: map['name']?.toString() ?? 'Safe Zone',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 150.0,
      iconPreset: (map['iconPreset'] as num?)?.toInt() ?? 0,
      notifyOnEntry: map['notifyOnEntry'] != false,
      notifyOnExit: map['notifyOnExit'] != false,
      targetRecipientUids: parseStringList(map['targetRecipientUids']),
      targetGroupIds: parseStringList(map['targetGroupIds']),
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      isEnabled: map['isEnabled'] != false,
    );
  }

  GeofenceModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    int? iconPreset,
    bool? notifyOnEntry,
    bool? notifyOnExit,
    List<String>? targetRecipientUids,
    List<String>? targetGroupIds,
    int? createdAt,
    bool? isEnabled,
  }) {
    return GeofenceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      iconPreset: iconPreset ?? this.iconPreset,
      notifyOnEntry: notifyOnEntry ?? this.notifyOnEntry,
      notifyOnExit: notifyOnExit ?? this.notifyOnExit,
      targetRecipientUids: targetRecipientUids ?? this.targetRecipientUids,
      targetGroupIds: targetGroupIds ?? this.targetGroupIds,
      createdAt: createdAt ?? this.createdAt,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
