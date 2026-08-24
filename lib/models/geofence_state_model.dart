class GeofenceStateModel {
  final String geofenceId;
  final bool isInside;
  final int lastEvaluatedAt;
  final String? lastTriggeredState; // 'entered' | 'exited' | null
  final int? lastTriggeredAt;

  const GeofenceStateModel({
    required this.geofenceId,
    required this.isInside,
    required this.lastEvaluatedAt,
    this.lastTriggeredState,
    this.lastTriggeredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'geofenceId': geofenceId,
      'isInside': isInside,
      'lastEvaluatedAt': lastEvaluatedAt,
      'lastTriggeredState': lastTriggeredState,
      'lastTriggeredAt': lastTriggeredAt,
    };
  }

  factory GeofenceStateModel.fromMap(Map<dynamic, dynamic> map, String geofenceId) {
    return GeofenceStateModel(
      geofenceId: geofenceId,
      isInside: map['isInside'] == true,
      lastEvaluatedAt: (map['lastEvaluatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      lastTriggeredState: map['lastTriggeredState']?.toString(),
      lastTriggeredAt: (map['lastTriggeredAt'] as num?)?.toInt(),
    );
  }

  GeofenceStateModel copyWith({
    String? geofenceId,
    bool? isInside,
    int? lastEvaluatedAt,
    String? lastTriggeredState,
    int? lastTriggeredAt,
  }) {
    return GeofenceStateModel(
      geofenceId: geofenceId ?? this.geofenceId,
      isInside: isInside ?? this.isInside,
      lastEvaluatedAt: lastEvaluatedAt ?? this.lastEvaluatedAt,
      lastTriggeredState: lastTriggeredState ?? this.lastTriggeredState,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
    );
  }
}
