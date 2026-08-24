class GroupLocationSessionModel {
  final String sessionId;
  final String groupId;
  final String createdBy;
  final int createdAt;
  final String title;
  final bool isActive;

  const GroupLocationSessionModel({
    required this.sessionId,
    required this.groupId,
    required this.createdBy,
    required this.createdAt,
    required this.title,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'groupId': groupId,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'title': title.trim(),
      'isActive': isActive,
    };
  }

  factory GroupLocationSessionModel.fromMap(Map<dynamic, dynamic> map, String groupId) {
    return GroupLocationSessionModel(
      sessionId: map['sessionId']?.toString() ?? '',
      groupId: map['groupId']?.toString() ?? groupId,
      createdBy: map['createdBy']?.toString() ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      title: map['title']?.toString() ?? 'Live Location Session',
      isActive: map['isActive'] == true,
    );
  }

  GroupLocationSessionModel copyWith({
    String? sessionId,
    String? groupId,
    String? createdBy,
    int? createdAt,
    String? title,
    bool? isActive,
  }) {
    return GroupLocationSessionModel(
      sessionId: sessionId ?? this.sessionId,
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      isActive: isActive ?? this.isActive,
    );
  }
}
